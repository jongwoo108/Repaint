import SwiftUI
import PencilKit

// MARK: - Brush Settings View
//
// 우측 플로팅 패널:
//  · 브러시 타입 3개 (watercolor / marker / pen) — 레시피 추천 표시
//  · 크기 슬라이더 — 레시피 size_range 범위로 제한
//  · 불투명도 표시 (레시피 기준, 참고용)

struct BrushSettingsView: View {
    @Binding var currentBrushType: String   // "watercolor" | "marker" | "pen"
    @Binding var currentInkWidth: CGFloat
    let sizeRange: BrushPreset.SizeRange    // 레시피 기준 범위
    let recommendedType: String             // 레시피 추천 타입
    let opacity: Double

    private let brushTypes: [(id: String, icon: String, label: String)] = [
        ("watercolor", "paintbrush.fill",     "수채화"),
        ("marker",     "paintbrush.pointed.fill", "마커"),
        ("pen",        "pencil",              "펜"),
    ]

    var body: some View {
        VStack(spacing: 16) {
            // 타입 선택
            VStack(spacing: 8) {
                ForEach(brushTypes, id: \.id) { brush in
                    brushTypeButton(brush)
                }
            }

            Divider().background(Color.white.opacity(0.25))

            // 크기 슬라이더
            VStack(spacing: 6) {
                // 미리보기 원
                Circle()
                    .fill(Color.white.opacity(0.85))
                    .frame(width: currentInkWidth * 0.6, height: currentInkWidth * 0.6)
                    .frame(width: 44, height: 44)
                    .animation(.easeOut(duration: 0.15), value: currentInkWidth)

                // 슬라이더 (세로)
                VerticalSlider(
                    value: $currentInkWidth,
                    range: sizeRange.min...sizeRange.max
                )
                .frame(width: 28, height: 120)

                HStack {
                    Text("\(Int(sizeRange.min))")
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.5))
                    Spacer()
                    Text("\(Int(sizeRange.max))")
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.5))
                }
                .frame(width: 44)
            }

            Divider().background(Color.white.opacity(0.25))

            // 불투명도 (참고용 — PencilKit은 필압으로 자동 조절)
            VStack(spacing: 3) {
                Image(systemName: "drop.halffull")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.6))
                Text("\(Int(opacity * 100))%")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 10)
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .frame(width: 60)
    }

    // MARK: - Brush Type Button

    private func brushTypeButton(_ brush: (id: String, icon: String, label: String)) -> some View {
        let isSelected = currentBrushType == brush.id
        let isRecommended = recommendedType == brush.id

        return Button {
            currentBrushType = brush.id
        } label: {
            VStack(spacing: 3) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: brush.icon)
                        .font(.system(size: 18))
                        .foregroundColor(isSelected ? .yellow : .white.opacity(0.6))
                        .frame(width: 36, height: 36)
                        .background(
                            isSelected
                                ? Color.yellow.opacity(0.2)
                                : Color.white.opacity(0.08)
                        )
                        .cornerRadius(8)

                    // 추천 뱃지
                    if isRecommended {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 7, height: 7)
                            .offset(x: 2, y: -2)
                    }
                }
                Text(brush.label)
                    .font(.system(size: 9))
                    .foregroundColor(isSelected ? .yellow : .white.opacity(0.45))
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Vertical Slider

private struct VerticalSlider: View {
    @Binding var value: CGFloat
    let range: ClosedRange<CGFloat>

    var body: some View {
        GeometryReader { geo in
            let trackHeight = geo.size.height
            let normalized = (value - range.lowerBound) / (range.upperBound - range.lowerBound)
            let thumbY = trackHeight * (1 - normalized)  // 위 = 큰 값

            ZStack(alignment: .top) {
                // 트랙
                Capsule()
                    .fill(Color.white.opacity(0.15))
                    .frame(width: 4)
                    .frame(maxWidth: .infinity)

                // 채워진 부분
                VStack {
                    Spacer(minLength: thumbY)
                    Capsule()
                        .fill(Color.yellow.opacity(0.6))
                        .frame(width: 4)
                        .frame(maxWidth: .infinity)
                }

                // 썸
                Circle()
                    .fill(Color.white)
                    .frame(width: 18, height: 18)
                    .shadow(color: .black.opacity(0.3), radius: 3)
                    .offset(y: thumbY - 9)
                    .frame(maxWidth: .infinity)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        let pct = 1 - (drag.location.y / trackHeight)
                        let clamped = min(max(pct, 0), 1)
                        value = range.lowerBound + clamped * (range.upperBound - range.lowerBound)
                    }
            )
        }
    }
}
