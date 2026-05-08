import SwiftUI

struct HistoryScreen: View {
    @EnvironmentObject private var store: PersistenceStore
    @EnvironmentObject private var appModel: AppViewModel

    var body: some View {
        NavigationStack {
            List {
                if store.scanHistory.isEmpty {
                    ContentUnavailableView("No scans yet", systemImage: "doc.text.viewfinder", description: Text("Capture an ingredient label to create your first scan history item."))
                } else {
                    ForEach(store.scanHistory) { record in
                        Button {
                            appModel.selectedRecord = record
                        } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(record.riskLevel.title)
                                        .font(.headline)
                                    Spacer()
                                    Text(record.createdAt.formatted(date: .abbreviated, time: .shortened))
                                        .foregroundStyle(.secondary)
                                }
                                Text(record.matches.map(\.allergenName).joined(separator: ", ").ifEmpty("No tracked allergens detected"))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .onDelete(perform: appModel.deleteHistory)
                }
            }
            .navigationTitle("History")
            .sheet(item: $appModel.selectedRecord) { record in
                ResultDetailView(record: record)
            }
        }
    }
}
