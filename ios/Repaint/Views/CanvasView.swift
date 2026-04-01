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
        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) { onDrawingChanged() }
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

// MARK: - Region Instruction Panel
// "지금 하늘 영역을 칠하세요" + 팁 + 팔레트

private struct RegionInstructionPanel: View {
    let guide: RegionGuide
    @Binding var selectedHex: String
    let onColorSelected: (UIColor) -> Void
    @State private var tipIndex = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // 영역 안내 문구
            HStack(spacing: 8) {
                Image(systemName: regionIcon(guide.region.label))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.yellow)
                Text("지금 \(regionKoreanName(guide.region.label)) 영역을 칠하세요")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
            }

            // 스트로크 힌트
            Text(guide.strokeHints.description)
                .font(.caption)
                .foregroundColor(.white.opacity(0.75))
                .lineLimit(2)

            // 팁 (있을 경우)
            if !guide.recipe.tips.isEmpty {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "lightbulb.fill")
                        .font(.caption2)
                        .foregroundColor(.yellow.opacity(0.8))
                    Text(guide.recipe.tips[tipIndex % guide.recipe.tips.count])
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.65))
                        .lineLimit(2)
                }
                .onTapGesture { tipIndex += 1 }  // 탭하면 다음 팁
            }

            Divider().background(Color.white.opacity(0.2))

            // 팔레트
            HStack {
                PaletteView(
                    palette: guide.recipe.palette,
                    selectedHex: $selectedHex,
                    onColorSelected: onColorSelected
                )
                Spacer()
                // 브러시 타입 배지
                Text(guide.recipe.brush.type)
                    .font(.caption2.weight(.medium))
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.12))
                    .cornerRadius(6)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .cornerRadius(18)
        .padding(.horizontal, 20)
        .padding(.bottom, 24)
    }

    private func regionKoreanName(_ label: RegionLabel) -> String {
        switch label {
        case .sky:        return "하늘"
        case .water:      return "물"
        case .vegetation: return "식물"
        case .flower:     return "꽃"
        case .ground:     return "지면"
        case .background: return "배경"
        }
    }

    private func regionIcon(_ label: RegionLabel) -> String {
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

// MARK: - Region Progress Ring

private struct RegionProgressRing: View {
    let progress: Float   // 0.0 ~ 1.0

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.2), lineWidth: 3)
            Circle()
                .trim(from: 0, to: CGFloat(progress))
                .stroke(
                    progress >= 0.7 ? Color.green : Color.yellow,
                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.3), value: progress)
            Text("\(Int(progress * 100))%")
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.white)
        }
        .frame(width: 36, height: 36)
    }
}

// MARK: - Session Complete Overlay

private struct CompletionOverlay: View {
    let onCompare: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.65).ignoresSafeArea()
            VStack(spacing: 24) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 64))
                    .foregroundColor(.yellow)
                VStack(spacing: 8) {
                    Text("완성!")
                        .font(.largeTitle.bold())
                        .foregroundColor(.white)
                    Text("모네 인상주의 스타일로\n그림이 완성되었습니다.")
                        .font(.title3)
                        .foregroundColor(.white.opacity(0.85))
                        .multilineTextAlignment(.center)
                }
                Button(action: onCompare) {
                    HStack(spacing: 8) {
                        Image(systemName: "rectangle.lefthalf.inset.filled.arrow.left")
                        Text("작품 비교하기")
                    }
                    .font(.body.weight(.semibold))
                    .foregroundColor(.black)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 14)
                    .background(Color.yellow)
                    .cornerRadius(16)
                }
                .padding(.top, 4)
            }
        }
    }
}

// MARK: - Canvas View

struct CanvasView: View {
    @ObservedObject var session: PaintingSessionViewModel
    @State private var selectedHex: String = ""
    @State private var showBrushSettings = false
    @State private var currentBrushType: String = "watercolor"
    @State private var showProgressPanel = false
    @State private var showComparison = false
    @StateObject private var gallery = GalleryViewModel()

    var body: some View {
        ZStack {
            // 캔버스 배경색
            canvasBackground

            // Layer 1: 원본 사진 참고용 (반투명)
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
                inkType: pkInkType(for: currentBrushType),
                inkColor: session.currentColor,
                inkWidth: session.currentInkWidth,
                onDrawingChanged: { session.updateProgress() }
            )

            // Layer 3: 가이드 오버레이 (스트로크 힌트 포함)
            GuideOverlayView(
                regions: session.paintingGuide.regionGuides.map { $0.region },
                activeRegionId: session.currentRegionGuide?.id,
                imageSize: session.originalPhoto.size,
                strokeHints: session.currentStrokeHints
            )

            // Layer 4: UI
            VStack(spacing: 0) {
                topBar
                Spacer()
                if let guide = session.currentRegionGuide {
                    RegionInstructionPanel(
                        guide: guide,
                        selectedHex: $selectedHex,
                        onColorSelected: { session.currentColor = $0 }
                    )
                }
            }

            // Layer 5: 브러시 설정 플로팅 패널 (우측)
            if let brush = session.currentBrush {
                HStack {
                    Spacer()
                    VStack {
                        // 브러시 설정 토글 버튼
                        Button {
                            withAnimation(.spring(response: 0.3)) {
                                showBrushSettings.toggle()
                            }
                        } label: {
                            Image(systemName: "paintbrush.pointed.fill")
                                .font(.system(size: 18))
                                .foregroundColor(showBrushSettings ? .yellow : .white)
                                .frame(width: 44, height: 44)
                                .background(Color.black.opacity(0.4))
                                .clipShape(Circle())
                        }
                        .padding(.top, 80)

                        if showBrushSettings {
                            BrushSettingsView(
                                currentBrushType: $currentBrushType,
                                currentInkWidth: $session.currentInkWidth,
                                sizeRange: brush.sizeRange,
                                recommendedType: brush.type,
                                opacity: brush.opacity
                            )
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                        }

                        Spacer()
                    }
                    .padding(.trailing, 12)
                }
            }
        }
        .ignoresSafeArea()
        .overlay(alignment: .top) {
            // 진행률 패널 (드롭다운)
            if showProgressPanel {
                progressPanel
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(10)
            }
        }
        .overlay {
            // 70% 도달 전환 프롬프트
            if session.showAdvancePrompt, let guide = session.currentRegionGuide {
                AdvancePromptView(
                    regionLabel: guide.region.label,
                    coverage: session.regionProgress[guide.id] ?? 0.7,
                    onContinue: { session.dismissAdvancePrompt() },
                    onAdvance: { session.confirmAdvance() }
                )
                .zIndex(20)
            }
        }
        .overlay {
            if session.isSessionComplete {
                CompletionOverlay(onCompare: { showComparison = true })
                    .zIndex(30)
            }
        }
        .fullScreenCover(isPresented: $showComparison) {
            let canvasSize = session.canvasView.bounds.size
            let bgHex = session.paintingGuide.styleRecipe.canvasSettings.backgroundColor
            let bgColor = UIColor(Color(hex: bgHex) ?? Color(red: 0.96, green: 0.94, blue: 0.91))
            let painted = gallery.renderFinalPainting(
                drawing: session.canvasView.drawing,
                size: canvasSize.width > 0 ? canvasSize : CGSize(width: 1024, height: 1366),
                backgroundColor: bgColor
            )
            ComparisonView(
                originalImage: session.originalPhoto,
                paintedImage: painted,
                onDismiss: { showComparison = false }
            )
        }
        .onAppear {
            if let guide = session.currentRegionGuide {
                selectedHex = guide.recipe.palette.first?.hex ?? ""
                currentBrushType = guide.recipe.brush.type
            }
        }
        .onChange(of: session.currentRegionGuide?.id) { _ in
            if let guide = session.currentRegionGuide {
                selectedHex = guide.recipe.palette.first?.hex ?? ""
                currentBrushType = guide.recipe.brush.type  // 레시피 추천 타입으로 자동 전환
            }
        }
    }

    // MARK: Private

    private func pkInkType(for type: String) -> PKInkingTool.InkType {
        switch type {
        case "watercolor": return .watercolor
        case "marker":     return .marker
        default:           return .pen
        }
    }

    private var canvasBackground: some View {
        let hex = session.paintingGuide.styleRecipe.canvasSettings.backgroundColor
        return (Color(hex: hex) ?? Color(red: 0.96, green: 0.94, blue: 0.91))
    }

    private var topBar: some View {
        HStack(alignment: .center, spacing: 0) {
            StepIndicator(currentStep: session.currentStep)

            Spacer()

            // 현재 region 진행률 링 (탭 → 진행률 패널)
            if let guide = session.currentRegionGuide {
                let progress = session.regionProgress[guide.id] ?? 0
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        showProgressPanel.toggle()
                    }
                } label: {
                    RegionProgressRing(progress: progress)
                }
                .padding(.trailing, 8)
            }

            // 참고 사진 토글
            Button {
                session.showReference.toggle()
            } label: {
                Image(systemName: session.showReference ? "eye.fill" : "eye.slash.fill")
                    .font(.system(size: 17))
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
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

    private var progressPanel: some View {
        PaintingProgressView(
            guides: session.paintingGuide.regionGuides,
            progress: session.regionProgress,
            completedIds: completedIds,
            currentId: session.currentRegionGuide?.id
        )
        .padding(.horizontal, 20)
        .padding(.top, 70)
        .onTapGesture {
            withAnimation(.spring(response: 0.3)) { showProgressPanel = false }
        }
    }

    private var completedIds: Set<String> { session.completedRegionIds }
}
