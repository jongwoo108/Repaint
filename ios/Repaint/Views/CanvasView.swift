import SwiftUI
import PencilKit

// MARK: - PencilKit UIViewRepresentable

struct PencilCanvasRepresentable: UIViewRepresentable {
    @Binding var canvasView: PKCanvasView
    let inkType: PKInkingTool.InkType
    let inkColor: UIColor
    let inkWidth: CGFloat
    let onDrawingChanged: () -> Void

    func makeUIView(context: Context) -> PKCanvasView {
        canvasView.drawingPolicy = .pencilOnly   // Apple Pencil 전용
        canvasView.backgroundColor = .clear
        canvasView.isOpaque = false
        canvasView.delegate = context.coordinator
        return canvasView
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        uiView.tool = PKInkingTool(inkType, color: inkColor, width: inkWidth)
    }

    func makeCoordinator() -> Coordinator { Coordinator(onDrawingChanged: onDrawingChanged) }

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        let onDrawingChanged: () -> Void
        init(onDrawingChanged: @escaping () -> Void) { self.onDrawingChanged = onDrawingChanged }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            onDrawingChanged()
        }
    }
}

// MARK: - Region Mask Overlay

private struct RegionMaskOverlay: View {
    let regions: [Region]
    let activeRegionId: String?
    let imageSize: CGSize  // 원본 사진 크기 — path 좌표계 기준

    var body: some View {
        Canvas { context, viewSize in
            // cgPath는 원본 이미지 좌표(points)로 되어 있으므로
            // view 크기에 맞게 스케일 변환 필요
            let scaleX = viewSize.width / imageSize.width
            let scaleY = viewSize.height / imageSize.height
            let transform = CGAffineTransform(scaleX: scaleX, y: scaleY)

            for region in regions {
                guard let cgPath = region.cgPath else { continue }
                let scaledPath = Path(cgPath).applying(transform)

                if region.id == activeRegionId {
                    // 활성 영역: 노란 테두리 + 연한 하이라이트
                    context.stroke(scaledPath, with: .color(.white.opacity(0.9)), lineWidth: 2.5)
                    context.fill(scaledPath, with: .color(.yellow.opacity(0.08)))
                } else {
                    // 비활성 영역: 어둡게 dimming
                    context.fill(scaledPath, with: .color(.black.opacity(0.45)))
                }
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Step Indicator

private struct StepIndicator: View {
    let currentStep: PaintingStep

    var body: some View {
        HStack(spacing: 6) {
            ForEach(PaintingStep.allCases, id: \.self) { step in
                VStack(spacing: 3) {
                    Capsule()
                        .fill(step == currentStep ? Color.yellow : Color.white.opacity(0.35))
                        .frame(height: 3)
                    Text(step.rawValue.capitalized)
                        .font(.system(size: 10, weight: step == currentStep ? .semibold : .regular))
                        .foregroundColor(step == currentStep ? .yellow : .white.opacity(0.5))
                }
            }
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - Guide Bottom Panel

private struct GuideBottomPanel: View {
    let guide: RegionGuide
    @Binding var currentColor: UIColor
    @State private var selectedHex: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(guide.region.label.rawValue.capitalized, systemImage: labelIcon(guide.region.label))
                    .font(.headline.bold())
                    .foregroundColor(.white)
                Spacer()
                Text(guide.recipe.brush.type)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.white.opacity(0.15))
                    .cornerRadius(6)
            }

            Text(guide.strokeHints.description)
                .font(.caption)
                .foregroundColor(.white.opacity(0.75))
                .lineLimit(2)

            // 팔레트
            HStack(spacing: 10) {
                ForEach(guide.recipe.palette) { color in
                    Button {
                        currentColor = color.uiColor
                        selectedHex = color.hex
                    } label: {
                        Circle()
                            .fill(Color(uiColor: color.uiColor))
                            .frame(width: 38, height: 38)
                            .overlay(
                                Circle()
                                    .strokeBorder(
                                        selectedHex == color.hex ? Color.white : Color.clear,
                                        lineWidth: 2.5
                                    )
                            )
                            .shadow(color: .black.opacity(0.3), radius: 2)
                    }
                }
            }
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .padding(.horizontal, 20)
        .padding(.bottom, 24)
        .onAppear {
            // 첫 번째 색상을 기본 선택으로
            if let first = guide.recipe.palette.first {
                selectedHex = first.hex
                currentColor = first.uiColor
            }
        }
        .onChange(of: guide.id) { _ in
            if let first = guide.recipe.palette.first {
                selectedHex = first.hex
                currentColor = first.uiColor
            }
        }
    }

    private func labelIcon(_ label: RegionLabel) -> String {
        switch label {
        case .sky:        return "cloud.fill"
        case .water:      return "drop.fill"
        case .vegetation: return "leaf.fill"
        case .flower:     return "camera.macro"
        case .ground:     return "mountain.2.fill"
        case .background: return "square.fill"
        }
    }
}

// MARK: - Session Complete Overlay

private struct CompletionOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.65).ignoresSafeArea()
            VStack(spacing: 20) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 64))
                    .foregroundColor(.yellow)
                Text("완성!")
                    .font(.largeTitle.bold())
                    .foregroundColor(.white)
                Text("모네 인상주의 스타일로\n그림이 완성되었습니다.")
                    .font(.title3)
                    .foregroundColor(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
            }
        }
    }
}

// MARK: - Canvas View

struct CanvasView: View {
    @ObservedObject var session: PaintingSessionViewModel

    var body: some View {
        ZStack {
            // 캔버스 배경색
            canvasBackground

            // Layer 1: 원본 사진 (반투명 참고용)
            if session.showReference {
                Image(uiImage: session.originalPhoto)
                    .resizable()
                    .scaledToFill()
                    .opacity(0.15)
                    .clipped()
            }

            // Layer 2: PencilKit 캔버스
            PencilCanvasRepresentable(
                canvasView: $session.canvasView,
                inkType: session.pkInkType,
                inkColor: session.currentColor,
                inkWidth: inkWidth,
                onDrawingChanged: { session.updateProgress() }
            )

            // Layer 3: Region 가이드 오버레이
            RegionMaskOverlay(
                regions: session.paintingGuide.regionGuides.map { $0.region },
                activeRegionId: session.currentRegionGuide?.id,
                imageSize: session.originalPhoto.size
            )

            // Layer 4: UI
            VStack(spacing: 0) {
                topBar
                Spacer()
                if let guide = session.currentRegionGuide {
                    GuideBottomPanel(guide: guide, currentColor: $session.currentColor)
                }
            }
        }
        .ignoresSafeArea()
        .overlay {
            if session.isSessionComplete { CompletionOverlay() }
        }
    }

    // MARK: Private

    private var canvasBackground: some View {
        let hex = session.paintingGuide.styleRecipe.canvasSettings.backgroundColor
        return (Color(hex: hex) ?? Color(red: 0.96, green: 0.94, blue: 0.91))
    }

    private var inkWidth: CGFloat {
        CGFloat(session.currentBrush?.sizeRange.min ?? 15)
    }

    private var topBar: some View {
        HStack(alignment: .center) {
            StepIndicator(currentStep: session.currentStep)
            Spacer()

            // 참고 사진 토글
            Button {
                session.showReference.toggle()
            } label: {
                Image(systemName: session.showReference ? "eye.fill" : "eye.slash.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.black.opacity(0.4))
                    .clipShape(Circle())
            }
            .padding(.trailing, 16)
        }
        .padding(.top, 16)
        .background(
            LinearGradient(
                colors: [.black.opacity(0.45), .clear],
                startPoint: .top, endPoint: .bottom
            )
        )
    }
}
