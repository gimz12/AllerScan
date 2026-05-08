import PhotosUI
import SwiftUI
import Translation

struct TranslationScreen: View {
    @EnvironmentObject private var appModel: AppViewModel
    @StateObject private var cameraModel = CameraCaptureModel()
    @Environment(\.dismiss) private var dismiss

    @State private var showResult = false
    @State private var capturedImage: UIImage?
    @State private var originalText: String?
    @State private var detectedLanguage: String?
    @State private var languageCode: String?
    @State private var isProcessing = false
    @State private var selectedPhoto: PhotosPickerItem?

    private let accentRed = Color(red: 0.83, green: 0.18, blue: 0.18)

    var body: some View {
        NavigationStack {
            ZStack {
                Group {
                    if showResult, let image = capturedImage, let text = originalText {
                        TranslationResultView(
                            sourceImage: image,
                            originalText: text,
                            detectedLanguage: detectedLanguage ?? "Unknown",
                            languageCode: languageCode,
                            trackedAllergens: appModel.trackedAllergens,
                            onScanAgain: {
                                showResult = false
                                capturedImage = nil
                                originalText = nil
                                detectedLanguage = nil
                                languageCode = nil
                            },
                            onAnalyze: { translatedText in
                                Task {
                                    await appModel.analyzeTranslatedText(translatedText)
                                    if appModel.selectedRecord != nil {
                                        dismiss()
                                    }
                                }
                            }
                        )
                    } else {
                        cameraScanView
                    }
                }

                // Full-screen loading overlay — covers everything during OCR or analysis.
                if isProcessing || appModel.isProcessingScan {
                    fullScreenLoadingOverlay
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var fullScreenLoadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.55)
                .ignoresSafeArea()
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.6)
                    .tint(.white)
                Text(loadingMessage)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            .padding(28)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.2), value: isProcessing)
        .animation(.easeInOut(duration: 0.2), value: appModel.isProcessingScan)
    }

    private var loadingMessage: String {
        if appModel.isProcessingScan { return "Analyzing ingredients..." }
        if isProcessing { return "Recognizing text..." }
        return "Working..."
    }

    private var cameraScanView: some View {
        VStack(spacing: 20) {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.black)
                .overlay {
                    if appModel.cameraPermissionGranted && cameraModel.isConfigured {
                        CameraPreview(session: cameraModel.session)
                            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                    } else {
                        VStack(spacing: 12) {
                            Image(systemName: "camera.metering.unknown")
                                .font(.system(size: 36))
                                .foregroundStyle(.white)
                            Text(cameraModel.statusMessage)
                                .foregroundStyle(.white.opacity(0.85))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                    }
                }
                .frame(height: 360)
                .overlay(alignment: .topLeading) {
                    HStack(spacing: 6) {
                        Image(systemName: "character.book.closed.fill")
                            .font(.caption)
                        Text("Translation Mode")
                            .font(.subheadline.weight(.semibold))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .padding()
                }

            Text("Point camera at a foreign language ingredient label")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            VStack(spacing: 10) {
                Button {
                    Task {
                        do {
                            let image = try await cameraModel.capturePhoto()
                            await processCapture(image)
                        } catch {
                            appModel.lastErrorMessage = error.localizedDescription
                        }
                    }
                } label: {
                    Label("Capture Label", systemImage: "camera.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(accentRed)
                .disabled(!appModel.cameraPermissionGranted || isProcessing || !cameraModel.isConfigured)

                PhotosPicker(selection: $selectedPhoto, matching: .images, photoLibrary: .shared()) {
                    Label("Choose from Photos", systemImage: "photo.on.rectangle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .disabled(isProcessing)
            }
            .onChange(of: selectedPhoto) { _, newItem in
                guard let newItem else { return }
                Task {
                    if let data = try? await newItem.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        await processCapture(image)
                    } else {
                        appModel.lastErrorMessage = "Could not load that photo. Try a different image."
                    }
                    selectedPhoto = nil
                }
            }

            Spacer()
        }
        .padding()
        .navigationTitle("Translation Mode")
        .task {
            await cameraModel.configureIfNeeded()
        }
    }

    private func processCapture(_ image: UIImage) async {
        isProcessing = true
        capturedImage = image

        do {
            let scanService = ScanService()
            let scan = try await scanService.recognizeMultiLanguage(from: image)
            originalText = scan.rawText

            let translationService = TranslationService()
            if let detected = translationService.detectLanguage(for: scan.rawText) {
                detectedLanguage = detected.name
                languageCode = detected.code
            } else {
                detectedLanguage = "Unknown"
                languageCode = nil
            }

            showResult = true
        } catch {
            appModel.lastErrorMessage = error.localizedDescription
        }

        isProcessing = false
    }
}
