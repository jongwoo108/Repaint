import Foundation

enum PaintingStep: String, CaseIterable {
    case background, midground, foreground, finish
}

struct StrokeHints {
    let direction: String
    let pattern: String
    let description: String
}

struct RegionGuide: Identifiable {
    let id: String          // region.id
    let region: Region
    let recipe: RegionRecipe
    let step: PaintingStep

    var strokeHints: StrokeHints {
        StrokeHints(
            direction: recipe.strokeGuide.direction,
            pattern: recipe.strokeGuide.pattern,
            description: recipe.strokeGuide.description
        )
    }
}

struct PaintingGuide {
    let styleRecipe: StyleRecipe
    let regionGuides: [RegionGuide]

    func guides(for step: PaintingStep) -> [RegionGuide] {
        regionGuides.filter { $0.step == step }
    }
}
