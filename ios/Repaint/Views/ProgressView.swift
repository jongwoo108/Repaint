import SwiftUI

// MARK: - Painting Progress View
//
// 상단 드로어로 펼치는 진행률 패널:
//  · 전체 진행률 바
//  · region별 커버리지 행 (완료 / 진행 중 / 미시작)

struct PaintingProgressView: View {
    let guides: [RegionGuide]
    let progress: [String: Float]
    let completedIds: Set<String>
    let currentId: String?

    var overallProgress: Float {
        guard !guides.isEmpty else { return 0 }
        return Float(completedIds.count) / Float(guides.count)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 전체 진행률
            overallBar

            Divider().background(Color.white.opacity(0.2))

            // Region별 진행률
            ForEach(guides) { guide in
                regionRow(guide)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .cornerRadius(16)
    }

    // MARK: - Overall Bar

    private var overallBar: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("전체 진행률")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.white)
                Spacer()
                Text("\(completedIds.count) / \(guides.count) 완료")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.65))
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.15))
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [.yellow, .green],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * CGFloat(overallProgress))
                        .animation(.easeOut(duration: 0.4), value: overallProgress)
                }
            }
            .frame(height: 6)
        }
    }

    // MARK: - Region Row

    private func regionRow(_ guide: RegionGuide) -> some View {
        let isCompleted = completedIds.contains(guide.id)
        let isCurrent   = guide.id == currentId
        let pct         = progress[guide.id] ?? 0

        return HStack(spacing: 10) {
            // 상태 아이콘
            ZStack {
                Circle()
                    .fill(rowColor(isCompleted: isCompleted, isCurrent: isCurrent).opacity(0.2))
                    .frame(width: 28, height: 28)
                Image(systemName: rowIcon(isCompleted: isCompleted, isCurrent: isCurrent))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(rowColor(isCompleted: isCompleted, isCurrent: isCurrent))
            }

            // region 이름
            Text(koreanName(guide.region.label))
                .font(.caption.weight(isCurrent ? .semibold : .regular))
                .foregroundColor(isCurrent ? .white : .white.opacity(0.7))
                .frame(width: 44, alignment: .leading)

            // 진행률 바
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.12))
                    Capsule()
                        .fill(rowColor(isCompleted: isCompleted, isCurrent: isCurrent).opacity(0.8))
                        .frame(width: geo.size.width * CGFloat(isCompleted ? 1 : pct))
                        .animation(.easeOut(duration: 0.3), value: pct)
                }
            }
            .frame(height: 5)

            // 퍼센트
            Text(isCompleted ? "✓" : "\(Int(pct * 100))%")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(rowColor(isCompleted: isCompleted, isCurrent: isCurrent))
                .frame(width: 28, alignment: .trailing)
        }
    }

    // MARK: - Helpers

    private func rowColor(isCompleted: Bool, isCurrent: Bool) -> Color {
        if isCompleted { return .green }
        if isCurrent   { return .yellow }
        return .white.opacity(0.4)
    }

    private func rowIcon(isCompleted: Bool, isCurrent: Bool) -> String {
        if isCompleted { return "checkmark" }
        if isCurrent   { return "pencil" }
        return "circle"
    }

    private func koreanName(_ label: RegionLabel) -> String {
        switch label {
        case .sky:        return "하늘"
        case .water:      return "물"
        case .vegetation: return "식물"
        case .flower:     return "꽃"
        case .ground:     return "지면"
        case .background: return "배경"
        }
    }
}

// MARK: - Advance Prompt
// "이 영역 70% 완료! 다음으로 넘어갈까요?"

struct AdvancePromptView: View {
    let regionLabel: RegionLabel
    let coverage: Float
    let onContinue: () -> Void
    let onAdvance: () -> Void

    private var koreanName: String {
        switch regionLabel {
        case .sky:        return "하늘"
        case .water:      return "물"
        case .vegetation: return "식물"
        case .flower:     return "꽃"
        case .ground:     return "지면"
        case .background: return "배경"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 16) {
                // 완료 아이콘
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.2))
                        .frame(width: 56, height: 56)
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.green)
                }

                VStack(spacing: 6) {
                    Text("\(koreanName) 영역 \(Int(coverage * 100))% 완료!")
                        .font(.headline.bold())
                        .foregroundColor(.white)
                    Text("다음 영역으로 넘어갈까요?\n더 그리고 싶다면 계속 그려도 됩니다.")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.75))
                        .multilineTextAlignment(.center)
                }

                HStack(spacing: 12) {
                    Button(action: onContinue) {
                        Text("계속 그리기")
                            .font(.body.weight(.medium))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.white.opacity(0.15))
                            .cornerRadius(14)
                    }

                    Button(action: onAdvance) {
                        HStack(spacing: 6) {
                            Text("다음으로")
                            Image(systemName: "arrow.right")
                        }
                        .font(.body.weight(.semibold))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.yellow)
                        .cornerRadius(14)
                    }
                }
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(.regularMaterial)
            )
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .background(Color.black.opacity(0.35).ignoresSafeArea())
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}
