import SwiftUI

// MARK: - Palette View
//
// 레시피 palette를 색상 스와치 행으로 표시.
// 탭 → currentColor 변경 / 길게 누르기 → 색상 이름 + 용도 툴팁

struct PaletteView: View {
    let palette: [PaletteColor]
    @Binding var selectedHex: String
    let onColorSelected: (UIColor) -> Void

    @State private var tooltip: PaletteColor? = nil

    var body: some View {
        HStack(spacing: 12) {
            ForEach(palette) { color in
                colorSwatch(color)
            }
        }
        .overlay(tooltipOverlay, alignment: .top)
    }

    // MARK: - Swatch

    private func colorSwatch(_ color: PaletteColor) -> some View {
        let isSelected = selectedHex.uppercased() == color.hex.uppercased()

        return Button {
            selectedHex = color.hex
            onColorSelected(color.uiColor)
            tooltip = nil
        } label: {
            ZStack {
                Circle()
                    .fill(Color(uiColor: color.uiColor))
                    .frame(width: 42, height: 42)
                    .shadow(color: .black.opacity(0.25), radius: 3, y: 1)

                // 선택 링
                if isSelected {
                    Circle()
                        .strokeBorder(Color.white, lineWidth: 3)
                        .frame(width: 42, height: 42)
                    Circle()
                        .strokeBorder(Color.black.opacity(0.2), lineWidth: 1)
                        .frame(width: 48, height: 48)
                }
            }
            .scaleEffect(isSelected ? 1.12 : 1.0)
            .animation(.spring(response: 0.25), value: isSelected)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.4).onEnded { _ in
                tooltip = color
                // 2초 후 자동 닫기
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    if tooltip?.hex == color.hex { tooltip = nil }
                }
            }
        )
    }

    // MARK: - Tooltip

    @ViewBuilder
    private var tooltipOverlay: some View {
        if let tip = tooltip {
            VStack(spacing: 2) {
                Text(tip.name)
                    .font(.caption.bold())
                    .foregroundColor(.white)
                Text(tip.usage)
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.75))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.black.opacity(0.8))
            .cornerRadius(8)
            .offset(y: -52)
            .transition(.opacity.combined(with: .scale(scale: 0.85)))
        }
    }
}

// MARK: - Preview helper

#if DEBUG
struct PaletteView_Preview: PreviewProvider {
    @State static var selectedHex = "#B8C9E0"
    static let samplePalette: [PaletteColor] = [
        PaletteColor(hex: "#B8C9E0", name: "Pale blue",    usage: "Base wash"),
        PaletteColor(hex: "#D4A8C7", name: "Lavender pink", usage: "Cloud highlights"),
        PaletteColor(hex: "#E8D5B7", name: "Warm cream",   usage: "Horizon glow"),
        PaletteColor(hex: "#9BAFC4", name: "Steel blue",   usage: "Upper sky depth"),
    ]
    static var previews: some View {
        ZStack {
            Color.gray
            PaletteView(
                palette: samplePalette,
                selectedHex: $selectedHex,
                onColorSelected: { _ in }
            )
        }
        .frame(height: 80)
        .previewLayout(.sizeThatFits)
    }
}
#endif
