import SwiftUI
import PencilKit
import Combine

@MainActor
class PaintingSessionViewModel: ObservableObject {
    // MARK: - Published State
    @Published var currentStep: PaintingStep = .background
    @Published var currentRegionGuide: RegionGuide?
    @Published var currentPalette: [PaletteColor] = []
    @Published var currentColor: UIColor = .black
    @Published var currentBrush: BrushPreset?
    @Published var currentInkWidth: CGFloat = 15
    @Published var currentStrokeHints: StrokeHints?
    @Published var regionProgress: [String: Float] = [:]
    @Published var canvasView = PKCanvasView()
    @Published var showReference: Bool = true
    @Published var isSessionComplete: Bool = false

    /// 70% 도달 시 표시하는 "다음 영역으로?" 확인 프롬프트
    @Published var showAdvancePrompt: Bool = false

    // MARK: - Data
    let originalPhoto: UIImage
    let paintingGuide: PaintingGuide
    private let coverageCalculator = CoverageCalculator()
    @Published private(set) var completedRegionIds: Set<String> = []

    /// 프롬프트를 이미 표시한 region ID (중복 방지)
    private var promptShownFor: String? = nil
    /// 디바운스용 태스크
    private var progressTask: Task<Void, Never>?

    init(photo: UIImage, regions: [Region], recipe: StyleRecipe) {
        self.originalPhoto = photo
        self.paintingGuide = GuideGeneratorService.generate(regions: regions, recipe: recipe)
        advanceToNextRegion()
    }

    // MARK: - Navigation

    func advanceToNextRegion() {
        let stepsInOrder: [PaintingStep] = [.background, .midground, .foreground, .finish]
        for step in stepsInOrder {
            let guides = paintingGuide.guides(for: step)
            if let next = guides.first(where: { !completedRegionIds.contains($0.id) }) {
                currentStep = step
                currentRegionGuide = next
                currentPalette = next.recipe.palette
                currentColor = next.recipe.palette.first?.uiColor ?? .black
                currentBrush = next.recipe.brush
                currentInkWidth = CGFloat(next.recipe.brush.sizeRange.min)
                currentStrokeHints = next.strokeHints
                promptShownFor = nil
                return
            }
        }
        isSessionComplete = true
    }

    func completeCurrentRegion() {
        guard let guide = currentRegionGuide else { return }
        completedRegionIds.insert(guide.id)
        showAdvancePrompt = false
        advanceToNextRegion()
    }

    /// 프롬프트에서 "다음으로" 선택 시
    func confirmAdvance() {
        completeCurrentRegion()
    }

    /// 프롬프트에서 "계속 그리기" 선택 시
    func dismissAdvancePrompt() {
        showAdvancePrompt = false
    }

    // MARK: - Progress

    /// PKCanvasViewDelegate에서 매 stroke마다 호출 — 0.8초 디바운스 적용
    func updateProgress() {
        progressTask?.cancel()
        progressTask = Task {
            try? await Task.sleep(for: .milliseconds(800))
            guard !Task.isCancelled else { return }
            calculateProgress()
        }
    }

    private func calculateProgress() {
        guard let guide = currentRegionGuide else { return }
        let coverage = coverageCalculator.calculateCoverage(
            drawing: canvasView.drawing,
            targetRegion: guide.region,
            canvasSize: canvasView.bounds.size
        )
        regionProgress[guide.id] = coverage

        // 70% 도달 — 아직 프롬프트를 표시하지 않은 경우에만
        if coverage >= 0.7, promptShownFor != guide.id {
            promptShownFor = guide.id
            showAdvancePrompt = true
        }
    }

    // MARK: - Computed

    var pkInkType: PKInkingTool.InkType {
        switch currentBrush?.type {
        case "watercolor": return .watercolor
        case "marker":     return .marker
        default:           return .pen
        }
    }

    /// 전체 완료율 (0.0 ~ 1.0)
    var overallProgress: Float {
        let total = paintingGuide.regionGuides.count
        guard total > 0 else { return 0 }
        return Float(completedRegionIds.count) / Float(total)
    }
}
