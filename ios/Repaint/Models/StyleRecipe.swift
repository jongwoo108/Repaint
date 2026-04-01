import Foundation
import UIKit

struct PaletteColor: Codable, Identifiable {
    var id: String { hex }
    let hex: String
    let name: String
    let usage: String

    var uiColor: UIColor {
        UIColor(hex: hex) ?? .black
    }
}

struct BrushPreset: Codable {
    let type: String        // "watercolor" | "marker" | "pen"
    let sizeRange: SizeRange
    let opacity: Double

    struct SizeRange: Codable {
        let min: CGFloat
        let max: CGFloat
    }

    enum CodingKeys: String, CodingKey {
        case type, sizeRange = "size_range", opacity
    }
}

struct StrokeGuide: Codable {
    let direction: String   // "horizontal" | "vertical" | "varied" | "radial"
    let pattern: String
    let description: String
}

struct RegionRecipe: Codable {
    let layer: String       // "background" | "midground" | "foreground"
    let palette: [PaletteColor]
    let brush: BrushPreset
    let strokeGuide: StrokeGuide
    let tips: [String]

    enum CodingKeys: String, CodingKey {
        case layer, palette, brush
        case strokeGuide = "stroke_guide"
        case tips
    }
}

struct FinishStep: Codable, Identifiable {
    var id: String { name }
    let name: String
    let palette: [PaletteColor]
    let brush: BrushPreset
    let instruction: String
}

struct FinishPass: Codable {
    let description: String
    let steps: [FinishStep]
}

struct CanvasSettings: Codable {
    let backgroundColor: String
    let suggestedCanvasSize: CanvasSize

    struct CanvasSize: Codable {
        let width: Int
        let height: Int
    }

    enum CodingKeys: String, CodingKey {
        case backgroundColor = "background_color"
        case suggestedCanvasSize = "suggested_canvas_size"
    }
}

struct StyleRecipe: Codable {
    let styleId: String
    let styleName: String
    let description: String
    let canvasSettings: CanvasSettings
    let paintingOrder: [String]
    let regionRecipes: [String: RegionRecipe]
    let finishPass: FinishPass

    enum CodingKeys: String, CodingKey {
        case styleId = "style_id"
        case styleName = "style_name"
        case description
        case canvasSettings = "canvas_settings"
        case paintingOrder = "painting_order"
        case regionRecipes = "region_recipes"
        case finishPass = "finish_pass"
    }

    func recipe(for label: RegionLabel) -> RegionRecipe? {
        regionRecipes[label.rawValue]
    }
}

// MARK: - UIColor hex helper
extension UIColor {
    convenience init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        switch hex.count {
        case 6:
            (r, g, b) = (int >> 16, int >> 8 & 0xFF, int & 0xFF)
        default:
            return nil
        }
        self.init(red: CGFloat(r)/255, green: CGFloat(g)/255, blue: CGFloat(b)/255, alpha: 1)
    }
}
