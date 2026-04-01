import Foundation
import CoreGraphics
import UIKit

enum RegionLabel: String, Codable {
    case sky, water, vegetation, flower, ground, background
}

struct Region: Identifiable {
    let id: String
    let label: RegionLabel
    let mask: CVPixelBuffer         // 513×513 binary mask
    let cgPath: CGPath?             // 원본 해상도로 스케일된 경계 경로
    let boundingRect: CGRect
    let areaRatio: Float            // 전체 이미지 대비 면적 비율
    var isCompleted: Bool = false
}
