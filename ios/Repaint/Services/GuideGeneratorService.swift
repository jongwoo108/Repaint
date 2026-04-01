import Foundation

struct GuideGeneratorService {
    static func generate(regions: [Region], recipe: StyleRecipe) -> PaintingGuide {
        let layerToStep: [String: PaintingStep] = [
            "background": .background,
            "midground": .midground,
            "foreground": .foreground,
        ]

        var regionGuides: [RegionGuide] = []
        for region in regions {
            guard let regionRecipe = recipe.recipe(for: region.label) else { continue }
            let step = layerToStep[regionRecipe.layer] ?? .background
            regionGuides.append(RegionGuide(
                id: region.id,
                region: region,
                recipe: regionRecipe,
                step: step
            ))
        }

        // painting_order 순서로 정렬
        let orderPriority: [PaintingStep: Int] = [.background: 0, .midground: 1, .foreground: 2, .finish: 3]
        regionGuides.sort { (orderPriority[$0.step] ?? 99) < (orderPriority[$1.step] ?? 99) }

        return PaintingGuide(styleRecipe: recipe, regionGuides: regionGuides)
    }
}
