import SwiftUI

// MARK: - Comparison View
//
// 원본 사진과 완성 작품을 드래그로 비교:
//  · 좌측: 원본 사진 (before)
//  · 우측: 완성 페인팅 (after)
//  · 중앙 드래그 핸들로 분할선 이동
//  · 하단: 저장 버튼 + 닫기 버튼

struct ComparisonView: View {
    let originalImage: UIImage
    let paintedImage: UIImage
    let onDismiss: () -> Void

    @StateObject private var gallery = GalleryViewModel()
    @State private var sliderPosition: CGFloat = 0.5   // 0.0(전체 원본) ~ 1.0(전체 작품)
    @State private var isDragging = false
    @State private var showShareSheet = false
    @State private var shareImage: UIImage?

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // MARK: - Canvas Layer
                canvasLayer(geo: geo)

                // MARK: - Divider + Handle
                dividerHandle(geo: geo)

                // MARK: - Labels
                labels(geo: geo)

                // MARK: - Bottom Controls
                VStack {
                    Spacer()
                    bottomControls
                }
            }
        }
        .ignoresSafeArea()
        .background(Color.black)
        .sheet(isPresented: $showShareSheet) {
            if let img = shareImage {
                ShareSheet(items: [img])
            }
        }
        .overlay {
            if case .saving = gallery.saveStatus {
                savingOverlay
            }
        }
        .overlay(alignment: .top) {
            if case .saved = gallery.saveStatus {
                savedBanner
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
            if case .failed(let msg) = gallery.saveStatus {
                errorBanner(msg)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }

    // MARK: - Canvas Layer

    private func canvasLayer(geo: GeometryProxy) -> some View {
        let dividerX = geo.size.width * sliderPosition

        return ZStack(alignment: .leading) {
            // After: 작품 (전체 너비)
            Image(uiImage: paintedImage)
                .resizable()
                .scaledToFill()
                .frame(width: geo.size.width, height: geo.size.height)
                .clipped()

            // Before: 원본 (왼쪽 dividerX만큼만 보임)
            Image(uiImage: originalImage)
                .resizable()
                .scaledToFill()
                .frame(width: geo.size.width, height: geo.size.height)
                .clipped()
                .mask(
                    Rectangle()
                        .frame(width: dividerX)
                        .frame(maxWidth: .infinity, alignment: .leading)
                )
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    isDragging = true
                    let newPos = value.location.x / geo.size.width
                    sliderPosition = min(max(newPos, 0), 1)
                }
                .onEnded { _ in
                    isDragging = false
                }
        )
    }

    // MARK: - Divider Handle

    private func dividerHandle(geo: GeometryProxy) -> some View {
        let dividerX = geo.size.width * sliderPosition

        return ZStack {
            // 분할선
            Rectangle()
                .fill(Color.white)
                .frame(width: 2)
                .frame(maxHeight: .infinity)
                .shadow(color: .black.opacity(0.4), radius: 4)
                .position(x: dividerX, y: geo.size.height / 2)

            // 드래그 핸들 원
            ZStack {
                Circle()
                    .fill(Color.white)
                    .frame(width: isDragging ? 52 : 44, height: isDragging ? 52 : 44)
                    .shadow(color: .black.opacity(0.3), radius: 6)
                    .animation(.spring(response: 0.25), value: isDragging)

                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                    Image(systemName: "chevron.right")
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.black.opacity(0.6))
            }
            .position(x: dividerX, y: geo.size.height / 2)
        }
        .allowsHitTesting(false)  // 터치는 canvasLayer의 gesture로 처리
    }

    // MARK: - Labels

    private func labels(geo: GeometryProxy) -> some View {
        VStack {
            HStack {
                // Before 라벨
                Text("원본")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.black.opacity(0.5))
                    .cornerRadius(8)
                    .padding(.leading, 20)
                    .opacity(sliderPosition > 0.1 ? 1 : 0)

                Spacer()

                // After 라벨
                Text("작품")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.black.opacity(0.5))
                    .cornerRadius(8)
                    .padding(.trailing, 20)
                    .opacity(sliderPosition < 0.9 ? 1 : 0)
            }
            .padding(.top, 60)

            Spacer()
        }
    }

    // MARK: - Bottom Controls

    private var bottomControls: some View {
        HStack(spacing: 16) {
            // 닫기
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 48, height: 48)
                    .background(Color.white.opacity(0.2))
                    .clipShape(Circle())
            }

            Spacer()

            // 공유 (나란히 비교 이미지)
            Button {
                shareImage = gallery.renderComparisonImage(
                    original: originalImage,
                    painted: paintedImage
                )
                showShareSheet = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "square.and.arrow.up")
                    Text("공유")
                }
                .font(.body.weight(.medium))
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background(Color.white.opacity(0.2))
                .cornerRadius(14)
            }

            // 사진 저장
            Button {
                Task { await gallery.saveToPhotos(image: paintedImage) }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.down.to.line")
                    Text("저장")
                }
                .font(.body.weight(.semibold))
                .foregroundColor(.black)
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background(Color.yellow)
                .cornerRadius(14)
            }
            .disabled(gallery.saveStatus == .saving || gallery.saveStatus == .saved)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 40)
        .padding(.top, 16)
        .background(
            LinearGradient(
                colors: [.clear, .black.opacity(0.6)],
                startPoint: .top, endPoint: .bottom
            )
        )
    }

    // MARK: - Status Overlays

    private var savingOverlay: some View {
        ZStack {
            Color.black.opacity(0.4).ignoresSafeArea()
            ProgressView()
                .progressViewStyle(.circular)
                .tint(.white)
                .scaleEffect(1.5)
        }
    }

    private var savedBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
            Text("사진 라이브러리에 저장되었습니다")
                .font(.subheadline.weight(.medium))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color.black.opacity(0.8))
        .cornerRadius(14)
        .padding(.top, 60)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                withAnimation { gallery.saveStatus = .idle }
            }
        }
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundColor(.red)
            Text(message)
                .font(.subheadline)
                .foregroundColor(.white)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color.black.opacity(0.8))
        .cornerRadius(14)
        .padding(.top, 60)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                withAnimation { gallery.saveStatus = .idle }
            }
        }
    }
}

// MARK: - Share Sheet

private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
