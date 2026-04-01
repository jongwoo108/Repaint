import SwiftUI

// MARK: - App Flow

enum AppFlow {
    case camera
    case segmenting(UIImage)
    case painting(UIImage, [Region], StyleRecipe)
    case error(String)
}

// MARK: - ContentView

@MainActor
struct ContentView: View {
    @State private var flow: AppFlow = .camera
    @StateObject private var segService = SegmentationService()

    var body: some View {
        Group {
            switch flow {
            case .camera:
                CameraView { photo in
                    flow = .segmenting(photo)
                }

            case .segmenting(let photo):
                SegmentingView(photo: photo)
                    .task { await runSegmentation(photo: photo) }

            case .painting(let photo, let regions, let recipe):
                PaintingView(photo: photo, regions: regions, recipe: recipe)

            case .error(let message):
                ErrorView(message: message) {
                    flow = .camera
                }
            }
        }
        .task {
            // 앱 시작 시 CoreML 모델 로드 (백그라운드에서 처리하되 MainActor 제약)
            try? segService.loadModel()
        }
    }

    private func runSegmentation(photo: UIImage) async {
        do {
            let regions = try await segService.segment(image: photo)
            let recipe = try StyleRecipeLoader.load(styleId: "monet_water_lilies")
            flow = .painting(photo, regions, recipe)
        } catch {
            flow = .error(error.localizedDescription)
        }
    }
}

// MARK: - Segmenting View

struct SegmentingView: View {
    let photo: UIImage

    var body: some View {
        ZStack {
            Image(uiImage: photo)
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
                .blur(radius: 8)
                .overlay(Color.black.opacity(0.5).ignoresSafeArea())

            VStack(spacing: 24) {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(.white)
                    .scaleEffect(1.5)
                Text("영역 분석 중...")
                    .font(.title3)
                    .foregroundColor(.white)
                Text("AI가 사진의 하늘, 물, 식물, 꽃, 지면을 구분합니다.")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
            }
            .padding()
        }
    }
}

// MARK: - Error View

struct ErrorView: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        ZStack {
            Color(white: 0.1).ignoresSafeArea()
            VStack(spacing: 24) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 56))
                    .foregroundColor(.orange)
                Text("오류가 발생했습니다")
                    .font(.title2.bold())
                    .foregroundColor(.white)
                Text(message)
                    .font(.body)
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                Button("다시 시도", action: onRetry)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
            }
        }
    }
}

// MARK: - Painting View (StateObject wrapper)

struct PaintingView: View {
    let photo: UIImage
    let regions: [Region]
    let recipe: StyleRecipe

    @StateObject private var session: PaintingSessionViewModel

    init(photo: UIImage, regions: [Region], recipe: StyleRecipe) {
        self.photo = photo
        self.regions = regions
        self.recipe = recipe
        _session = StateObject(
            wrappedValue: PaintingSessionViewModel(photo: photo, regions: regions, recipe: recipe)
        )
    }

    var body: some View {
        CanvasView(session: session)
    }
}
