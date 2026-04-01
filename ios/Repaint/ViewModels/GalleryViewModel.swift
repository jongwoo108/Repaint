import SwiftUI
import PencilKit
import Photos

// MARK: - Save Status

enum SaveStatus: Equatable {
    case idle
    case saving
    case saved
    case failed(String)
}

// MARK: - Gallery ViewModel

@MainActor
final class GalleryViewModel: ObservableObject {
    @Published var saveStatus: SaveStatus = .idle

    // MARK: - Render

    /// PKDrawing + 배경색 → UIImage (작품 최종 이미지)
    func renderFinalPainting(
        drawing: PKDrawing,
        size: CGSize,
        backgroundColor: UIColor
    ) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            // 1. 배경색 채우기
            backgroundColor.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))

            // 2. PKDrawing을 이미지로 렌더링하여 합성
            let drawingImage = drawing.image(from: CGRect(origin: .zero, size: size), scale: 2.0)
            drawingImage.draw(in: CGRect(origin: .zero, size: size))
        }
    }

    /// 원본 사진 + 작품 이미지를 나란히 붙인 비교 이미지 (공유용)
    func renderComparisonImage(original: UIImage, painted: UIImage) -> UIImage {
        let w = original.size.width
        let h = original.size.height
        let totalSize = CGSize(width: w * 2, height: h)

        let renderer = UIGraphicsImageRenderer(size: totalSize)
        return renderer.image { _ in
            original.draw(in: CGRect(x: 0, y: 0, width: w, height: h))
            painted.draw(in: CGRect(x: w, y: 0, width: w, height: h))
        }
    }

    // MARK: - Save to Photos

    func saveToPhotos(image: UIImage) async {
        saveStatus = .saving

        let authorized = await requestPhotosAuthorization()
        guard authorized else {
            saveStatus = .failed("사진 라이브러리 접근 권한이 필요합니다.")
            return
        }

        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            }
            saveStatus = .saved
        } catch {
            saveStatus = .failed(error.localizedDescription)
        }
    }

    // MARK: - Private

    private func requestPhotosAuthorization() async -> Bool {
        let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        switch status {
        case .authorized, .limited:
            return true
        case .notDetermined:
            let result = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
            return result == .authorized || result == .limited
        default:
            return false
        }
    }
}
