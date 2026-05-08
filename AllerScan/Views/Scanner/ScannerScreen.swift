import PhotosUI
import SwiftUI

struct ScannerScreen: View {
    @EnvironmentObject private var appModel: AppViewModel
    @EnvironmentObject private var store: PersistenceStore
    @StateObject private var cameraModel = CameraCaptureModel()
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPhoto: PhotosPickerItem?

    var body: some View {
        NavigationStack {
            ZStack {
                content
                if appModel.isProcessingScan {
                    fullScreenLoadingOverlay
                }
            }
            .navigationTitle("Scanner")
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
            .task {
                await cameraModel.configureIfNeeded()
            }
        }
    }

    private var content: some View {
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
                    Text("Tracking: \(store.activeProfile?.name ?? "Profile")")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        .padding()
                }

            Text(cameraModel.statusMessage)
                .foregroundStyle(.secondary)

            VStack(spacing: 10) {
                Button {
                    Task {
                        do {
                            let image = try await cameraModel.capturePhoto()
                            await appModel.processCapturedImage(image)
                            if appModel.selectedRecord != nil {
                                dismiss()
                            }
                        } catch {
                            appModel.lastErrorMessage = error.localizedDescription
                        }
                    }
                } label: {
                    Label("Scan Ingredient Label", systemImage: "viewfinder.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!appModel.cameraPermissionGranted || appModel.isProcessingScan || !cameraModel.isConfigured)

                PhotosPicker(selection: $selectedPhoto, matching: .images, photoLibrary: .shared()) {
                    Label("Choose from Photos", systemImage: "photo.on.rectangle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .disabled(appModel.isProcessingScan)
            }
            .onChange(of: selectedPhoto) { _, newItem in
                guard let newItem else { return }
                Task {
                    if let data = try? await newItem.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        await appModel.processCapturedImage(image)
                        if appModel.selectedRecord != nil {
                            dismiss()
                        }
                    } else {
                        appModel.lastErrorMessage = "Could not load that photo. Try a different image."
                    }
                    selectedPhoto = nil
                }
            }

            List(appModel.trackedAllergens) { allergen in
                Label(allergen.name, systemImage: "checkmark.shield")
            }
            .frame(maxHeight: 220)
            .scrollContentBackground(.hidden)
        }
        .padding()
    }

    private var fullScreenLoadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.55)
                .ignoresSafeArea()
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.6)
                    .tint(.white)
                Text("Analyzing ingredients...")
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
        .animation(.easeInOut(duration: 0.2), value: appModel.isProcessingScan)
    }
}
