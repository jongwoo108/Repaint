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
    @Published var currentStrokeHints: StrokeHints?
    @Published var regionProgress: [String: Float] = [:]
    @Published var canvasView = PKCanvasView()
    @Published var showReference: Bool = true
    @Published var isSessionComplete: Bool = false

    // MARK: - Data
    let originalPhoto: UIImage
    let paintingGuide: PaintingGuide
    private let coverageCalculator = CoverageCalculator()
    private var completedRegionIds: Set<String> = []

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
                currentStrokeHints = next.strokeHints
                return
            }
        }
        isSessionComplete = true
    }

    func completeCurrentRegion() {
        guard let guide = currentRegionGuide else { return }
        completedRegionIds.insert(guide.id)
        advanceToNextRegion()
    }

    // MARK: - Progress

    func updateProgress() {
        guard let guide = currentRegionGuide else { return }
        let coverage = coverageCalculator.calculateCoverage(
            drawing: canvasView.drawing,
            targetRegion: guide.region,
            canvasSize: canvasView.bounds.size
        )
        regionProgress[guide.id] = coverage

        if coverage >= 0.7 {
            completeCurrentRegion()
        }
    }

    // MARK: - Brush

    var pkInkType: PKInkingTool.InkType {
        switch currentBrush?.type {
        case "watercolor": return .watercolor
        case "marker": return .marker
        default: return .pen
        }
    }
}
