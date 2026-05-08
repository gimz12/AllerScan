import SwiftUI

struct ScannerScreen: View {
    @EnvironmentObject private var appModel: AppViewModel
    @EnvironmentObject private var store: PersistenceStore
    @StateObject private var cameraModel = CameraCaptureModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
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

                if appModel.isProcessingScan {
                    ProgressView("Analyzing ingredients...")
                } else {
                    Text(cameraModel.statusMessage)
                        .foregroundStyle(.secondary)
                }

                Button {
                    Task {
                        do {
                            let image = try await cameraModel.capturePhoto()
                            await appModel.processCapturedImage(image)
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

                List(appModel.trackedAllergens) { allergen in
                    Label(allergen.name, systemImage: "checkmark.shield")
                }
                .frame(maxHeight: 220)
                .scrollContentBackground(.hidden)
            }
            .padding()
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
            .sheet(item: $appModel.selectedRecord) { record in
                ResultDetailView(record: record)
            }
        }
    }
}
