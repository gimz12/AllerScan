import SwiftUI

struct SyncStatusRow: View {
    @EnvironmentObject private var syncService: SyncService

    private var icon: String {
        switch syncService.status {
        case .syncing:      return "arrow.triangle.2.circlepath"
        case .idle:         return "checkmark.icloud.fill"
        case .offline:      return "icloud.slash.fill"
        case .error:        return "exclamationmark.icloud.fill"
        case .notSignedIn:  return "icloud.slash"
        }
    }

    private var iconColor: Color {
        switch syncService.status {
        case .syncing:      return .blue
        case .idle:         return .green
        case .offline:      return .orange
        case .error:        return .red
        case .notSignedIn:  return .secondary
        }
    }

    private var title: String {
        switch syncService.status {
        case .syncing:      return "Syncing…"
        case .idle:         return "Up to date"
        case .offline:      return "Offline"
        case .error:        return "Sync failed"
        case .notSignedIn:  return "Not signed in"
        }
    }

    private var subtitle: String {
        switch syncService.status {
        case .syncing:
            return syncService.pendingOperations > 1
                ? "\(syncService.pendingOperations) changes uploading"
                : "Saving your changes…"
        case .idle:
            if let last = syncService.lastSyncDate {
                return "Last synced \(relativeText(from: last))"
            }
            return "Connected to cloud"
        case .offline:
            return "Changes will upload when you're back online"
        case .error(let message):
            return message
        case .notSignedIn:
            return "Sign in to back up your data"
        }
    }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 36, height: 36)
                Group {
                    if syncService.status == .syncing {
                        ProgressView().tint(iconColor)
                    } else {
                        Image(systemName: icon)
                            .foregroundStyle(iconColor)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.bold())
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }

    private func relativeText(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: .now)
    }
}
