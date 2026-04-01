import PencilKit
import CoreGraphics
import UIKit

struct CoverageCalculator {
    /// 사용자 stroke가 target region을 얼마나 커버하는지 계산 (0.0 ~ 1.0)
    /// 0.7 이상이면 다음 단계 전환
    func calculateCoverage(
        drawing: PKDrawing,
        targetRegion: Region,
        canvasSize: CGSize
    ) -> Float {
        // 1. PKDrawing → UIImage 래스터라이즈 (target 영역만)
        let strokeImage = drawing.image(from: CGRect(origin: .zero, size: canvasSize), scale: 1.0)
        guard let strokeCG = strokeImage.cgImage else { return 0 }

        // 2. 마스크 크기 통일 (513×513 기준)
        let maskSize = 513
        let strokeMask = rasterize(cgImage: strokeCG, size: maskSize)
        let targetMask = extractMask(from: targetRegion.mask, size: maskSize)

        // 3. Coverage = intersection / target area
        var intersection = 0
        var targetArea = 0
        for i in 0..<(maskSize * maskSize) {
            let inTarget = targetMask[i] > 0
            let inStroke = strokeMask[i] > 0
            if inTarget { targetArea += 1 }
            if inTarget && inStroke { intersection += 1 }
        }
        guard targetArea > 0 else { return 0 }
        return Float(intersection) / Float(targetArea)
    }

    private func rasterize(cgImage: CGImage, size: Int) -> [UInt8] {
        var pixels = [UInt8](repeating: 0, count: size * size)
        let colorSpace = CGColorSpaceCreateDeviceGray()
        guard let ctx = CGContext(
            data: &pixels, width: size, height: size,
            bitsPerComponent: 8, bytesPerRow: size,
            space: colorSpace, bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { return pixels }
        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: size, height: size))
        return pixels
    }

    private func extractMask(from pixelBuffer: CVPixelBuffer, size: Int) -> [UInt8] {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddress(pixelBuffer) else { return [] }
        let ptr = base.assumingMemoryBound(to: UInt8.self)
        let count = size * size
        return Array(UnsafeBufferPointer(start: ptr, count: count))
    }
}
