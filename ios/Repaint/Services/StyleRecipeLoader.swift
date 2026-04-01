import Foundation

enum RecipeLoaderError: Error {
    case fileNotFound(String)
    case decodingFailed(Error)
}

struct StyleRecipeLoader {
    static func load(styleId: String) throws -> StyleRecipe {
        guard let url = Bundle.main.url(
            forResource: styleId,
            withExtension: "json",
            subdirectory: "Recipes"
        ) else {
            throw RecipeLoaderError.fileNotFound(styleId)
        }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(StyleRecipe.self, from: data)
        } catch {
            throw RecipeLoaderError.decodingFailed(error)
        }
    }
}
