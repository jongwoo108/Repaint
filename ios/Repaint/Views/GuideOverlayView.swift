import SwiftUI

// MARK: - Guide Overlay View
//
// 세 개의 레이어로 구성:
//  1. 비활성 region → 반투명 어둠 마스크
//  2. 활성 region  → 점선 테두리 + 연한 하이라이트
//  3. 스트로크 방향 힌트 화살표 (활성 region 위)

struct GuideOverlayView: View {
    let regions: [Region]
    let activeRegionId: String?
    let imageSize: CGSize          // 원본 사진 크기 (path 좌표계 기준)
    let strokeHints: StrokeHints?

    @State private var dashPhase: CGFloat = 0

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, viewSize in
                let scaleX = viewSize.width  / imageSize.width
                let scaleY = viewSize.height / imageSize.height
                let transform = CGAffineTransform(scaleX: scaleX, y: scaleY)

                // 1. 비활성 region dimming
                for region in regions where region.id != activeRegionId {
                    guard let cgPath = region.cgPath else { continue }
                    context.fill(
                        Path(cgPath).applying(transform),
                        with: .color(.black.opacity(0.42))
                    )
                }

                // 2. 활성 region 하이라이트 + 점선 테두리
                if let active = regions.first(where: { $0.id == activeRegionId }),
                   let cgPath = active.cgPath {
                    let path = Path(cgPath).applying(transform)
                    // 연한 노란 fill
                    context.fill(path, with: .color(.yellow.opacity(0.07)))
                    // 흰색 실선 테두리
                    context.stroke(path, with: .color(.white.opacity(0.6)), lineWidth: 1.5)
                    // 노란 점선 애니메이션 테두리
                    var dashed = context
                    dashed.stroke(
                        path,
                        with: .color(.yellow.opacity(0.9)),
                        style: StrokeStyle(lineWidth: 2, dash: [8, 5], dashPhase: dashPhase)
                    )
                }

                // 3. 스트로크 방향 힌트
                if let active = regions.first(where: { $0.id == activeRegionId }),
                   let hints = strokeHints {
                    let rect = active.boundingRect.applying(transform)
                    drawStrokeHints(context: context, in: rect, hints: hints)
                }
            }
            .onChange(of: timeline.date) { _ in
                dashPhase -= 1.5  // 점선 애니메이션
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: - Stroke Direction Hints

    private func drawStrokeHints(
        context: GraphicsContext,
        in rect: CGRect,
        hints: StrokeHints
    ) {
        let arrowColor = GraphicsContext.Shading.color(.white.opacity(0.55))
        let arrowLength: CGFloat = min(rect.width, rect.height) * 0.18
        let arrowHeadSize: CGFloat = arrowLength * 0.28

        switch hints.direction {
        case "horizontal":
            let ys = [rect.midY - rect.height * 0.2,
                      rect.midY,
                      rect.midY + rect.height * 0.2]
            for y in ys {
                drawHorizontalArrow(context: context, center: CGPoint(x: rect.midX, y: y),
                                    length: arrowLength, headSize: arrowHeadSize, shading: arrowColor)
            }

        case "vertical":
            let xs = [rect.midX - rect.width * 0.2,
                      rect.midX,
                      rect.midX + rect.width * 0.2]
            for x in xs {
                drawVerticalArrow(context: context, center: CGPoint(x: x, y: rect.midY),
                                  length: arrowLength, headSize: arrowHeadSize, shading: arrowColor)
            }

        case "radial":
            let center = CGPoint(x: rect.midX, y: rect.midY)
            let angles: [CGFloat] = [0, .pi / 2, .pi, .pi * 3 / 2]
            for angle in angles {
                let dx = cos(angle) * arrowLength * 0.6
                let dy = sin(angle) * arrowLength * 0.6
                let from = CGPoint(x: center.x - dx, y: center.y - dy)
                let to   = CGPoint(x: center.x + dx, y: center.y + dy)
                drawArrow(context: context, from: from, to: to,
                          headSize: arrowHeadSize, shading: arrowColor)
            }

        default: // "varied", "stipple" 등 — 분산된 짧은 획 표시
            let positions: [CGPoint] = [
                CGPoint(x: rect.midX - rect.width * 0.2, y: rect.midY - rect.height * 0.15),
                CGPoint(x: rect.midX + rect.width * 0.15, y: rect.midY),
                CGPoint(x: rect.midX - rect.width * 0.1, y: rect.midY + rect.height * 0.18),
            ]
            for pos in positions {
                drawHorizontalArrow(context: context, center: pos,
                                    length: arrowLength * 0.7, headSize: arrowHeadSize * 0.7,
                                    shading: arrowColor)
            }
        }
    }

    private func drawHorizontalArrow(
        context: GraphicsContext, center: CGPoint,
        length: CGFloat, headSize: CGFloat,
        shading: GraphicsContext.Shading
    ) {
        let from = CGPoint(x: center.x - length / 2, y: center.y)
        let to   = CGPoint(x: center.x + length / 2, y: center.y)
        drawArrow(context: context, from: from, to: to, headSize: headSize, shading: shading)
    }

    private func drawVerticalArrow(
        context: GraphicsContext, center: CGPoint,
        length: CGFloat, headSize: CGFloat,
        shading: GraphicsContext.Shading
    ) {
        let from = CGPoint(x: center.x, y: center.y - length / 2)
        let to   = CGPoint(x: center.x, y: center.y + length / 2)
        drawArrow(context: context, from: from, to: to, headSize: headSize, shading: shading)
    }

    private func drawArrow(
        context: GraphicsContext,
        from: CGPoint, to: CGPoint,
        headSize: CGFloat,
        shading: GraphicsContext.Shading
    ) {
        var path = Path()
        // 화살표 몸통
        path.move(to: from)
        path.addLine(to: to)
        context.stroke(path, with: shading, style: StrokeStyle(lineWidth: 1.8, lineCap: .round))

        // 화살표 머리
        let angle = atan2(to.y - from.y, to.x - from.x)
        var head = Path()
        head.move(to: to)
        head.addLine(to: CGPoint(
            x: to.x - headSize * cos(angle - .pi / 6),
            y: to.y - headSize * sin(angle - .pi / 6)
        ))
        head.move(to: to)
        head.addLine(to: CGPoint(
            x: to.x - headSize * cos(angle + .pi / 6),
            y: to.y - headSize * sin(angle + .pi / 6)
        ))
        context.stroke(head, with: shading, style: StrokeStyle(lineWidth: 1.8, lineCap: .round))
    }
}
