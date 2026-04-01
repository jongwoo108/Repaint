import UIKit
import CoreImage
import CoreGraphics

// MARK: - UIImage ↔ CIImage

extension UIImage {
    var ciImage: CIImage? {
        if let ci = self.ciImage { return ci }
        guard let cg = cgImage else { return nil }
        return CIImage(cgImage: cg)
    }
}

// MARK: - Resize

extension UIImage {
    func resized(to size: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }

    func resized(toFit maxDimension: CGFloat) -> UIImage {
        let scale = maxDimension / max(size.width, size.height)
        guard scale < 1 else { return self }
        return resized(to: CGSize(width: size.width * scale, height: size.height * scale))
    }
}

// MARK: - Segmentation Mask Overlay (디버그용)

extension UIImage {
    /// 세그멘테이션 region들을 색상 오버레이로 합성한 이미지를 반환 (디버그/프리뷰용)
    func withRegionOverlay(_ regions: [Region], alpha: CGFloat = 0.4) -> UIImage {
        let classColors: [RegionLabel: UIColor] = [
            .sky:        UIColor(red: 0.53, green: 0.81, blue: 0.92, alpha: 1),
            .water:      UIColor(red: 0.25, green: 0.64, blue: 0.87, alpha: 1),
            .vegetation: UIColor(red: 0.13, green: 0.55, blue: 0.13, alpha: 1),
            .flower:     UIColor(red: 1.00, green: 0.41, blue: 0.71, alpha: 1),
            .ground:     UIColor(red: 0.55, green: 0.45, blue: 0.33, alpha: 1),
        ]

        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            draw(at: .zero)
            for region in regions {
                guard let path = region.cgPath,
                      let color = classColors[region.label] else { continue }
                ctx.cgContext.setFillColor(color.withAlphaComponent(alpha).cgColor)
                ctx.cgContext.addPath(path)
                ctx.cgContext.fillPath()
            }
        }
    }
}

// MARK: - Pixel Buffer → UIImage

func pixelBufferToUIImage(_ pixelBuffer: CVPixelBuffer) -> UIImage? {
    let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
    let context = CIContext()
    guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return nil }
    return UIImage(cgImage: cgImage)
}
