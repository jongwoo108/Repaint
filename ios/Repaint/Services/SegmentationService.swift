import CoreML
import Vision
import CoreImage
import UIKit

enum SegmentationError: Error {
    case modelNotFound
    case inferenceFailed(Error)
    case invalidOutput
}

// ADE20K class ID → 5-class ID (CoreML 모델이 이미 5-class로 변환된 경우 1:1)
private let labelMap: [Int: RegionLabel] = [
    1: .sky,
    2: .water,
    3: .vegetation,
    4: .flower,
    5: .ground,
]

@MainActor
class SegmentationService {
    private var visionModel: VNCoreMLModel?

    func loadModel() throws {
        guard let modelURL = Bundle.main.url(forResource: "DeepLabV3", withExtension: "mlpackage") else {
            throw SegmentationError.modelNotFound
        }
        let config = MLModelConfiguration()
        config.computeUnits = .cpuAndNeuralEngine
        let mlModel = try MLModel(contentsOf: modelURL, configuration: config)
        self.visionModel = try VNCoreMLModel(for: mlModel)
    }

    func segment(image: UIImage) async throws -> [Region] {
        guard let model = visionModel else { throw SegmentationError.modelNotFound }
        guard let cgImage = image.cgImage else { throw SegmentationError.invalidOutput }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNCoreMLRequest(model: model) { request, error in
                if let error {
                    continuation.resume(throwing: SegmentationError.inferenceFailed(error))
                    return
                }
                guard let obs = request.results?.first as? VNCoreMLFeatureValueObservation,
                      let multiArray = obs.featureValue.multiArrayValue else {
                    continuation.resume(throwing: SegmentationError.invalidOutput)
                    return
                }
                do {
                    let regions = try Self.extractRegions(from: multiArray, originalSize: image.size)
                    continuation.resume(returning: regions)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
            request.imageCropAndScaleOption = .scaleFill

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: SegmentationError.inferenceFailed(error))
            }
        }
    }

    private static func extractRegions(
        from multiArray: MLMultiArray,
        originalSize: CGSize
    ) throws -> [Region] {
        // multiArray shape: [1, 6, 513, 513] — class logits
        // argmax per pixel → class ID map
        let height = 513
        let width = 513
        var classMap = [[Int]](repeating: [Int](repeating: 0, count: width), count: height)

        for y in 0..<height {
            for x in 0..<width {
                var maxVal = Float(-Float.infinity)
                var maxClass = 0
                for c in 0..<6 {
                    let idx = [0, c, y, x] as [NSNumber]
                    let val = multiArray[idx].floatValue
                    if val > maxVal { maxVal = val; maxClass = c }
                }
                classMap[y][x] = maxClass
            }
        }

        var regions: [Region] = []
        for (classId, label) in labelMap {
            guard let region = buildRegion(
                classMap: classMap,
                targetClass: classId,
                label: label,
                mapSize: CGSize(width: width, height: height),
                originalSize: originalSize
            ) else { continue }
            regions.append(region)
        }
        return regions
    }

    private static func buildRegion(
        classMap: [[Int]],
        targetClass: Int,
        label: RegionLabel,
        mapSize: CGSize,
        originalSize: CGSize
    ) -> Region? {
        let h = Int(mapSize.height)
        let w = Int(mapSize.width)
        var pixels: [(Int, Int)] = []

        for y in 0..<h {
            for x in 0..<w {
                if classMap[y][x] == targetClass { pixels.append((x, y)) }
            }
        }
        guard pixels.count > 100 else { return nil }

        let areaRatio = Float(pixels.count) / Float(h * w)
        let scaleX = originalSize.width / mapSize.width
        let scaleY = originalSize.height / mapSize.height

        // Bounding rect
        let xs = pixels.map { CGFloat($0.0) * scaleX }
        let ys = pixels.map { CGFloat($0.1) * scaleY }
        let boundingRect = CGRect(
            x: xs.min()!, y: ys.min()!,
            width: xs.max()! - xs.min()!,
            height: ys.max()! - ys.min()!
        )

        // CGPath from contour (simplified: bounding path)
        let path = CGMutablePath()
        path.addRect(boundingRect)

        // Build binary mask as CVPixelBuffer (513×513, kCVPixelFormatType_OneComponent8)
        var pixelBuffer: CVPixelBuffer?
        CVPixelBufferCreate(nil, w, h, kCVPixelFormatType_OneComponent8, nil, &pixelBuffer)
        guard let pb = pixelBuffer else { return nil }
        CVPixelBufferLockBaseAddress(pb, [])
        if let base = CVPixelBufferGetBaseAddress(pb) {
            let ptr = base.assumingMemoryBound(to: UInt8.self)
            for y in 0..<h {
                for x in 0..<w {
                    ptr[y * w + x] = classMap[y][x] == targetClass ? 255 : 0
                }
            }
        }
        CVPixelBufferUnlockBaseAddress(pb, [])

        return Region(
            id: "\(label.rawValue)_\(targetClass)",
            label: label,
            mask: pb,
            cgPath: path,
            boundingRect: boundingRect,
            areaRatio: areaRatio
        )
    }
}
