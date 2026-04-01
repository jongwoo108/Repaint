import SwiftUI
import AVFoundation
import PhotosUI

// MARK: - Camera Session ViewModel

@MainActor
final class CameraViewModel: NSObject, ObservableObject {
    @Published var capturedPhoto: UIImage?
    @Published var errorMessage: String?

    private let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private(set) var previewLayer: AVCaptureVideoPreviewLayer?

    func setup() {
        guard AVCaptureDevice.authorizationStatus(for: .video) != .denied else {
            errorMessage = "카메라 접근 권한이 필요합니다. 설정 앱에서 허용해 주세요."
            return
        }
        session.beginConfiguration()
        session.sessionPreset = .photo

        guard
            let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
            let input = try? AVCaptureDeviceInput(device: device),
            session.canAddInput(input)
        else {
            session.commitConfiguration()
            errorMessage = "카메라를 사용할 수 없습니다."
            return
        }
        session.addInput(input)
        if session.canAddOutput(photoOutput) { session.addOutput(photoOutput) }
        session.commitConfiguration()
    }

    func start() {
        guard !session.isRunning else { return }
        Task.detached { [weak self] in self?.session.startRunning() }
    }

    func stop() {
        guard session.isRunning else { return }
        Task.detached { [weak self] in self?.session.stopRunning() }
    }

    func capture() {
        let settings = AVCapturePhotoSettings()
        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    func makePreviewLayer(bounds: CGRect) -> AVCaptureVideoPreviewLayer {
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        layer.frame = bounds
        previewLayer = layer
        return layer
    }
}

extension CameraViewModel: AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        guard error == nil,
              let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else { return }
        Task { @MainActor in self.capturedPhoto = image }
    }
}

// MARK: - Camera Preview (UIViewRepresentable)

private struct CameraPreviewView: UIViewRepresentable {
    let cameraVM: CameraViewModel

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .black
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        // previewLayer가 없으면 생성, 있으면 frame만 업데이트
        if cameraVM.previewLayer == nil {
            let layer = cameraVM.makePreviewLayer(bounds: uiView.bounds)
            uiView.layer.addSublayer(layer)
        } else {
            cameraVM.previewLayer?.frame = uiView.bounds
        }
    }
}

// MARK: - Library Picker (PHPickerViewController)

private struct LibraryPickerView: UIViewControllerRepresentable {
    let onPicked: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ vc: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: LibraryPickerView
        init(_ parent: LibraryPickerView) { self.parent = parent }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            parent.dismiss()
            guard let provider = results.first?.itemProvider,
                  provider.canLoadObject(ofClass: UIImage.self) else { return }
            provider.loadObject(ofClass: UIImage.self) { [weak self] object, _ in
                guard let image = object as? UIImage else { return }
                DispatchQueue.main.async { self?.parent.onPicked(image) }
            }
        }
    }
}

// MARK: - CameraView

struct CameraView: View {
    let onPhotoTaken: (UIImage) -> Void

    @StateObject private var vm = CameraViewModel()
    @State private var showLibraryPicker = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            CameraPreviewView(cameraVM: vm).ignoresSafeArea()

            VStack {
                // 안내 텍스트
                Text("정원이나 풍경 사진을 촬영하세요")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.4))
                    .cornerRadius(20)
                    .padding(.top, 48)

                Spacer()

                // 하단 컨트롤
                HStack(spacing: 56) {
                    // 라이브러리 버튼
                    Button {
                        showLibraryPicker = true
                    } label: {
                        Image(systemName: "photo.on.rectangle")
                            .font(.system(size: 26))
                            .foregroundColor(.white)
                            .frame(width: 56, height: 56)
                            .background(Color.white.opacity(0.2))
                            .clipShape(Circle())
                    }

                    // 촬영 버튼
                    Button(action: vm.capture) {
                        ZStack {
                            Circle()
                                .strokeBorder(Color.white, lineWidth: 4)
                                .frame(width: 84, height: 84)
                            Circle()
                                .fill(Color.white.opacity(0.9))
                                .frame(width: 70, height: 70)
                        }
                    }

                    // 빈 공간 (대칭 유지)
                    Spacer().frame(width: 56)
                }
                .padding(.bottom, 52)
            }

            // 오류 배너
            if let msg = vm.errorMessage {
                VStack {
                    Text(msg)
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.red.opacity(0.85))
                        .cornerRadius(10)
                        .padding(.top, 60)
                    Spacer()
                }
            }
        }
        .onAppear {
            vm.setup()
            vm.start()
        }
        .onDisappear { vm.stop() }
        .onChange(of: vm.capturedPhoto) { photo in
            if let photo { onPhotoTaken(photo) }
        }
        .sheet(isPresented: $showLibraryPicker) {
            LibraryPickerView(onPicked: onPhotoTaken)
        }
    }
}
