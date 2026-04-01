import XCTest
import PencilKit
@testable import Repaint

// MARK: - StyleRecipe JSON 디코딩 테스트

final class StyleRecipeDecodingTests: XCTestCase {

    private var recipe: StyleRecipe!

    override func setUpWithError() throws {
        // 테스트 번들에서 JSON 로드 (Xcode 테스트 타겟에 파일 포함 필요)
        guard let url = Bundle(for: Self.self).url(
            forResource: "monet_water_lilies", withExtension: "json", subdirectory: "Recipes"
        ) else {
            // 파일이 테스트 번들에 없으면 앱 번들에서 시도
            guard let appUrl = Bundle.main.url(
                forResource: "monet_water_lilies", withExtension: "json", subdirectory: "Recipes"
            ) else {
                throw XCTSkip("monet_water_lilies.json을 찾을 수 없음 — 테스트 타겟에 파일 추가 필요")
            }
            let data = try Data(contentsOf: appUrl)
            recipe = try JSONDecoder().decode(StyleRecipe.self, from: data)
            return
        }
        let data = try Data(contentsOf: url)
        recipe = try JSONDecoder().decode(StyleRecipe.self, from: data)
    }

    func test_styleId() {
        XCTAssertEqual(recipe.styleId, "monet_water_lilies")
    }

    func test_paintingOrder() {
        XCTAssertEqual(recipe.paintingOrder, ["background", "midground", "foreground", "finish"])
    }

    func test_allFiveRegionsPresent() {
        let labels: [RegionLabel] = [.sky, .water, .vegetation, .flower, .ground]
        for label in labels {
            XCTAssertNotNil(recipe.recipe(for: label), "\(label.rawValue) 레시피 누락")
        }
    }

    func test_skyIsBackgroundLayer() {
        XCTAssertEqual(recipe.recipe(for: .sky)?.layer, "background")
    }

    func test_vegetationIsMidgroundLayer() {
        XCTAssertEqual(recipe.recipe(for: .vegetation)?.layer, "midground")
    }

    func test_flowerIsForegroundLayer() {
        XCTAssertEqual(recipe.recipe(for: .flower)?.layer, "foreground")
    }

    func test_skyPaletteNotEmpty() {
        XCTAssertFalse(recipe.recipe(for: .sky)?.palette.isEmpty ?? true)
    }

    func test_brushTypeValues() {
        let validTypes = ["watercolor", "marker", "pen"]
        for (key, regionRecipe) in recipe.regionRecipes {
            XCTAssertTrue(
                validTypes.contains(regionRecipe.brush.type),
                "\(key) brush.type '\(regionRecipe.brush.type)' 가 유효하지 않음"
            )
        }
    }

    func test_paletteHexFormat() {
        for (key, regionRecipe) in recipe.regionRecipes {
            for color in regionRecipe.palette {
                XCTAssertTrue(
                    color.hex.hasPrefix("#") && color.hex.count == 7,
                    "\(key) palette hex '\(color.hex)' 형식 오류 (예: #RRGGBB)"
                )
            }
        }
    }

    func test_canvasBackgroundColorFormat() {
        let bg = recipe.canvasSettings.backgroundColor
        XCTAssertTrue(bg.hasPrefix("#") && bg.count == 7, "canvas background_color 형식 오류")
    }

    func test_finishPassHasSteps() {
        XCTAssertFalse(recipe.finishPass.steps.isEmpty, "finish_pass.steps가 비어 있음")
    }
}

// MARK: - GuideGeneratorService 매핑 테스트

final class GuideGeneratorTests: XCTestCase {

    // 테스트용 더미 Region 생성 헬퍼
    private func makeRegion(label: RegionLabel) -> Region {
        var pixelBuffer: CVPixelBuffer?
        CVPixelBufferCreate(nil, 10, 10, kCVPixelFormatType_OneComponent8, nil, &pixelBuffer)
        return Region(
            id: "\(label.rawValue)_test",
            label: label,
            mask: pixelBuffer!,
            cgPath: CGPath(rect: CGRect(x: 0, y: 0, width: 100, height: 100), transform: nil),
            boundingRect: CGRect(x: 0, y: 0, width: 100, height: 100),
            areaRatio: 0.2
        )
    }

    private func makeTestRecipe() throws -> StyleRecipe {
        // 인라인 최소 레시피 JSON (Bundle 의존 없음)
        let json = """
        {
          "style_id": "test_style",
          "style_name": "Test",
          "description": "Test recipe",
          "canvas_settings": {
            "background_color": "#FFFFFF",
            "suggested_canvas_size": { "width": 2048, "height": 1536 }
          },
          "painting_order": ["background", "midground", "foreground", "finish"],
          "region_recipes": {
            "sky":        { "layer": "background",  "palette": [{"hex":"#B8C9E0","name":"Blue","usage":"Base"}], "brush": {"type":"watercolor","size_range":{"min":20,"max":60},"opacity":0.4}, "stroke_guide": {"direction":"horizontal","pattern":"long_sweeping","description":"Sweep"}, "tips": [] },
            "water":      { "layer": "background",  "palette": [{"hex":"#4A7B6F","name":"Teal","usage":"Base"}], "brush": {"type":"watercolor","size_range":{"min":15,"max":45},"opacity":0.5}, "stroke_guide": {"direction":"horizontal","pattern":"short_dabs","description":"Dabs"}, "tips": [] },
            "vegetation": { "layer": "midground",   "palette": [{"hex":"#3B6B35","name":"Green","usage":"Base"}], "brush": {"type":"marker","size_range":{"min":10,"max":30},"opacity":0.6}, "stroke_guide": {"direction":"varied","pattern":"stipple","description":"Cluster"}, "tips": [] },
            "flower":     { "layer": "foreground",  "palette": [{"hex":"#E8A5C8","name":"Pink","usage":"Base"}], "brush": {"type":"pen","size_range":{"min":5,"max":15},"opacity":0.8}, "stroke_guide": {"direction":"radial","pattern":"circular","description":"Radial"}, "tips": [] },
            "ground":     { "layer": "midground",   "palette": [{"hex":"#8B7355","name":"Brown","usage":"Base"}], "brush": {"type":"watercolor","size_range":{"min":15,"max":40},"opacity":0.5}, "stroke_guide": {"direction":"horizontal","pattern":"wash","description":"Wash"}, "tips": [] }
          },
          "finish_pass": {
            "description": "Final pass",
            "steps": [{"name":"Highlight","palette":[{"hex":"#FFFFFF","name":"White","usage":"Sparkle"}],"brush":{"type":"pen","size_range":{"min":2,"max":5},"opacity":0.9},"instruction":"Add dots"}]
          }
        }
        """
        return try JSONDecoder().decode(StyleRecipe.self, from: json.data(using: .utf8)!)
    }

    func test_guideCount_matchesRegions() throws {
        let recipe = try makeTestRecipe()
        let regions = RegionLabel.allCases
            .filter { $0 != .background }
            .map { makeRegion(label: $0) }

        let guide = GuideGeneratorService.generate(regions: regions, recipe: recipe)
        XCTAssertEqual(guide.regionGuides.count, 5)
    }

    func test_paintingOrder_backgroundBeforeForeground() throws {
        let recipe = try makeTestRecipe()
        let regions = [.sky, .flower, .ground].map { makeRegion(label: $0) }
        let guide = GuideGeneratorService.generate(regions: regions, recipe: recipe)

        let steps = guide.regionGuides.map { $0.step }
        let bgIndex = steps.firstIndex(of: .background)!
        let fgIndex = steps.firstIndex(of: .foreground)!
        XCTAssertLessThan(bgIndex, fgIndex, "background가 foreground보다 먼저 나와야 함")
    }

    func test_skyMapsToBackgroundStep() throws {
        let recipe = try makeTestRecipe()
        let guide = GuideGeneratorService.generate(
            regions: [makeRegion(label: .sky)], recipe: recipe
        )
        XCTAssertEqual(guide.regionGuides.first?.step, .background)
    }

    func test_flowerMapsToForegroundStep() throws {
        let recipe = try makeTestRecipe()
        let guide = GuideGeneratorService.generate(
            regions: [makeRegion(label: .flower)], recipe: recipe
        )
        XCTAssertEqual(guide.regionGuides.first?.step, .foreground)
    }

    func test_unknownRegionLabel_isSkipped() throws {
        let recipe = try makeTestRecipe()
        let backgroundRegion = makeRegion(label: .background)  // 레시피에 없음
        let guide = GuideGeneratorService.generate(
            regions: [backgroundRegion], recipe: recipe
        )
        XCTAssertEqual(guide.regionGuides.count, 0, "레시피 없는 region은 가이드에서 제외되어야 함")
    }
}

// MARK: - PaintingSessionViewModel 플로우 테스트

final class PaintingSessionFlowTests: XCTestCase {

    private func makeRegion(label: RegionLabel) -> Region {
        var pixelBuffer: CVPixelBuffer?
        CVPixelBufferCreate(nil, 10, 10, kCVPixelFormatType_OneComponent8, nil, &pixelBuffer)
        return Region(
            id: "\(label.rawValue)_test",
            label: label,
            mask: pixelBuffer!,
            cgPath: nil,
            boundingRect: .zero,
            areaRatio: 0.2
        )
    }

    private func makeMinimalRecipe() throws -> StyleRecipe {
        let json = """
        {
          "style_id": "test", "style_name": "Test", "description": "",
          "canvas_settings": {"background_color":"#FFFFFF","suggested_canvas_size":{"width":100,"height":100}},
          "painting_order": ["background","midground","foreground","finish"],
          "region_recipes": {
            "sky":    {"layer":"background", "palette":[{"hex":"#AAAAAA","name":"A","usage":""}], "brush":{"type":"pen","size_range":{"min":5,"max":10},"opacity":1.0}, "stroke_guide":{"direction":"h","pattern":"p","description":"d"}, "tips":[]},
            "flower": {"layer":"foreground", "palette":[{"hex":"#BBBBBB","name":"B","usage":""}], "brush":{"type":"pen","size_range":{"min":5,"max":10},"opacity":1.0}, "stroke_guide":{"direction":"h","pattern":"p","description":"d"}, "tips":[]}
          },
          "finish_pass": {"description":"","steps":[]}
        }
        """
        return try JSONDecoder().decode(StyleRecipe.self, from: json.data(using: .utf8)!)
    }

    @MainActor
    func test_firstStepIsBackground() throws {
        let recipe = try makeMinimalRecipe()
        let regions = [makeRegion(label: .sky), makeRegion(label: .flower)]
        let vm = PaintingSessionViewModel(
            photo: UIImage(), regions: regions, recipe: recipe
        )
        XCTAssertEqual(vm.currentStep, .background)
    }

    @MainActor
    func test_firstRegionIsSky() throws {
        let recipe = try makeMinimalRecipe()
        let regions = [makeRegion(label: .sky), makeRegion(label: .flower)]
        let vm = PaintingSessionViewModel(
            photo: UIImage(), regions: regions, recipe: recipe
        )
        XCTAssertEqual(vm.currentRegionGuide?.region.label, .sky)
    }

    @MainActor
    func test_completingAllRegions_setsSessionComplete() throws {
        let recipe = try makeMinimalRecipe()
        let regions = [makeRegion(label: .sky)]
        let vm = PaintingSessionViewModel(
            photo: UIImage(), regions: regions, recipe: recipe
        )
        vm.completeCurrentRegion()
        XCTAssertTrue(vm.isSessionComplete)
    }

    @MainActor
    func test_stepAdvancesAfterRegionComplete() throws {
        let recipe = try makeMinimalRecipe()
        // sky(background) → flower(foreground) 순서
        let regions = [makeRegion(label: .sky), makeRegion(label: .flower)]
        let vm = PaintingSessionViewModel(
            photo: UIImage(), regions: regions, recipe: recipe
        )
        XCTAssertEqual(vm.currentStep, .background)
        vm.completeCurrentRegion()
        XCTAssertEqual(vm.currentStep, .foreground)
    }

    @MainActor
    func test_paletteUpdatesOnStepChange() throws {
        let recipe = try makeMinimalRecipe()
        let regions = [makeRegion(label: .sky), makeRegion(label: .flower)]
        let vm = PaintingSessionViewModel(
            photo: UIImage(), regions: regions, recipe: recipe
        )
        let skyPalette = vm.currentPalette
        vm.completeCurrentRegion()
        let flowerPalette = vm.currentPalette
        // 다른 region이므로 팔레트 hex가 달라야 함
        XCTAssertNotEqual(skyPalette.first?.hex, flowerPalette.first?.hex)
    }
}

// MARK: - RegionLabel 헬퍼

extension RegionLabel: CaseIterable {
    public static var allCases: [RegionLabel] {
        [.sky, .water, .vegetation, .flower, .ground, .background]
    }
}
