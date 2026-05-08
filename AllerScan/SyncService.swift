import Combine
import FirebaseAuth
import FirebaseFirestore
import Foundation
import Network

enum SyncStatus: Equatable {
    case notSignedIn
    case offline
    case idle
    case syncing
    case error(message: String)
}

@MainActor
final class SyncService: ObservableObject {
    @Published private(set) var status: SyncStatus = .notSignedIn
    @Published private(set) var lastSyncDate: Date?
    @Published private(set) var pendingOperations: Int = 0
    @Published private(set) var isOnline: Bool = true

    /// Set by AllerScanApp so SyncService can apply a remote snapshot during a manual pull.
    var applyRemoteSnapshot: ((RemoteSnapshot) throws -> Void)?

    private let db = Firestore.firestore()
    private let monitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "AllerScan.SyncService.NetworkMonitor")

    private var userID: String? { Auth.auth().currentUser?.uid }

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let online = path.status == .satisfied
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isOnline = online
                self.recomputeStatus()
            }
        }
        monitor.start(queue: monitorQueue)
        recomputeStatus()
    }

    deinit {
        monitor.cancel()
    }

    func updateAuthState(isAuthenticated: Bool) {
        recomputeStatus(authenticated: isAuthenticated)
    }

    func markSyncedNow() {
        lastSyncDate = .now
        recomputeStatus()
    }

    func syncNow() async {
        guard userID != nil else {
            status = .notSignedIn
            return
        }
        guard isOnline else {
            status = .offline
            return
        }
        status = .syncing
        do {
            let snapshot = try await pullAll()
            try applyRemoteSnapshot?(snapshot)
            lastSyncDate = .now
            status = .idle
        } catch {
            status = .error(message: error.localizedDescription)
        }
    }

    private func incrementPending() {
        pendingOperations += 1
        if status != .syncing { status = .syncing }
    }

    private func decrementPending(error: Error? = nil) {
        pendingOperations = max(0, pendingOperations - 1)
        if let error {
            status = .error(message: error.localizedDescription)
            return
        }
        if pendingOperations == 0 {
            lastSyncDate = .now
            recomputeStatus(clearError: true)
        }
    }

    private func recomputeStatus(authenticated: Bool? = nil, clearError: Bool = false) {
        let signedIn = authenticated ?? (userID != nil)
        guard signedIn else { status = .notSignedIn; return }
        guard isOnline else { status = .offline; return }
        if pendingOperations > 0 { status = .syncing; return }
        if !clearError, case .error = status { return }
        status = .idle
    }

    // MARK: - Profiles

    func upload(profile: UserProfile) {
        guard let uid = userID else { return }
        let data: [String: Any] = [
            "id": profile.id.uuidString,
            "name": profile.name,
            "trackedAllergenIDs": profile.trackedAllergenIDs,
            "createdAt": Timestamp(date: profile.createdAt),
            "updatedAt": Timestamp(date: .now)
        ]
        incrementPending()
        Task {
            do {
                try await db.collection("users").document(uid)
                    .collection("profiles").document(profile.id.uuidString)
                    .setData(data, merge: true)
                decrementPending()
            } catch {
                decrementPending(error: error)
            }
        }
    }

    func deleteProfile(id: UUID) {
        guard let uid = userID else { return }
        incrementPending()
        Task {
            let profileRef = db.collection("users").document(uid)
                .collection("profiles").document(id.uuidString)
            await self.deleteAllDocuments(in: profileRef.collection("scans"))
            await self.deleteAllDocuments(in: profileRef.collection("customAllergens"))
            do {
                try await profileRef.delete()
                decrementPending()
            } catch {
                decrementPending(error: error)
            }
        }
    }

    // MARK: - Scans

    func upload(scan: ScanRecord, profileID: UUID) {
        guard let uid = userID else { return }
        let data: [String: Any] = [
            "id": scan.id.uuidString,
            "rawText": scan.rawText,
            "normalizedText": scan.normalizedText,
            "foundIngredientsText": scan.foundIngredientsText,
            "matches": (try? JSONEncoder().encode(scan.matches)).flatMap { String(data: $0, encoding: .utf8) } ?? "[]",
            "riskLevel": scan.riskLevel.rawValue,
            "createdAt": Timestamp(date: scan.createdAt),
            "updatedAt": Timestamp(date: .now)
        ]
        incrementPending()
        Task {
            do {
                try await db.collection("users").document(uid)
                    .collection("profiles").document(profileID.uuidString)
                    .collection("scans").document(scan.id.uuidString)
                    .setData(data, merge: true)
                decrementPending()
            } catch {
                decrementPending(error: error)
            }
        }
    }

    func deleteScan(id: UUID, profileID: UUID) {
        guard let uid = userID else { return }
        incrementPending()
        Task {
            do {
                try await db.collection("users").document(uid)
                    .collection("profiles").document(profileID.uuidString)
                    .collection("scans").document(id.uuidString)
                    .delete()
                decrementPending()
            } catch {
                decrementPending(error: error)
            }
        }
    }

    // MARK: - Custom Allergens

    func upload(customAllergen: Allergen, profileID: UUID) {
        guard let uid = userID else { return }
        let data: [String: Any] = [
            "id": customAllergen.id,
            "name": customAllergen.name,
            "aliases": customAllergen.aliases,
            "createdAt": Timestamp(date: .now),
            "updatedAt": Timestamp(date: .now)
        ]
        incrementPending()
        Task {
            do {
                try await db.collection("users").document(uid)
                    .collection("profiles").document(profileID.uuidString)
                    .collection("customAllergens").document(customAllergen.id)
                    .setData(data, merge: true)
                decrementPending()
            } catch {
                decrementPending(error: error)
            }
        }
    }

    func deleteCustomAllergen(id: String, profileID: UUID) {
        guard let uid = userID else { return }
        incrementPending()
        Task {
            do {
                try await db.collection("users").document(uid)
                    .collection("profiles").document(profileID.uuidString)
                    .collection("customAllergens").document(id)
                    .delete()
                decrementPending()
            } catch {
                decrementPending(error: error)
            }
        }
    }

    // MARK: - Pull all

    struct RemoteSnapshot {
        let profiles: [UserProfile]
        let scansByProfile: [UUID: [ScanRecord]]
        let customAllergensByProfile: [UUID: [CustomAllergenRecord]]
    }

    func pullAll() async throws -> RemoteSnapshot {
        guard let uid = userID else {
            return RemoteSnapshot(profiles: [], scansByProfile: [:], customAllergensByProfile: [:])
        }

        let profilesSnapshot = try await db.collection("users").document(uid)
            .collection("profiles").getDocuments()

        var profiles: [UserProfile] = []
        var scansByProfile: [UUID: [ScanRecord]] = [:]
        var customsByProfile: [UUID: [CustomAllergenRecord]] = [:]

        for doc in profilesSnapshot.documents {
            guard let profile = decodeProfile(from: doc.data()) else { continue }
            profiles.append(profile)

            let scansSnap = try await doc.reference.collection("scans").getDocuments()
            scansByProfile[profile.id] = scansSnap.documents.compactMap { decodeScan(from: $0.data(), profileID: profile.id) }

            let customsSnap = try await doc.reference.collection("customAllergens").getDocuments()
            customsByProfile[profile.id] = customsSnap.documents.compactMap { decodeCustomAllergen(from: $0.data(), profileID: profile.id) }
        }

        return RemoteSnapshot(profiles: profiles, scansByProfile: scansByProfile, customAllergensByProfile: customsByProfile)
    }

    // MARK: - Decoding helpers

    private func decodeProfile(from data: [String: Any]) -> UserProfile? {
        guard let idString = data["id"] as? String,
              let id = UUID(uuidString: idString),
              let name = data["name"] as? String,
              let createdAt = (data["createdAt"] as? Timestamp)?.dateValue()
        else {
            return nil
        }
        let trackedIDs = data["trackedAllergenIDs"] as? [String] ?? []
        return UserProfile(id: id, name: name, trackedAllergenIDs: trackedIDs, createdAt: createdAt)
    }

    private func decodeScan(from data: [String: Any], profileID: UUID) -> ScanRecord? {
        guard let idString = data["id"] as? String,
              let id = UUID(uuidString: idString),
              let rawText = data["rawText"] as? String,
              let normalizedText = data["normalizedText"] as? String,
              let riskLevelRaw = data["riskLevel"] as? String,
              let riskLevel = RiskLevel(rawValue: riskLevelRaw),
              let createdAt = (data["createdAt"] as? Timestamp)?.dateValue()
        else {
            return nil
        }
        let foundText = data["foundIngredientsText"] as? String ?? rawText
        let matchesJSON = data["matches"] as? String ?? "[]"
        let matches = (try? JSONDecoder().decode([DetectedAllergen].self, from: Data(matchesJSON.utf8))) ?? []
        return ScanRecord(
            id: id,
            rawText: rawText,
            normalizedText: normalizedText,
            foundIngredientsText: foundText,
            matches: matches,
            riskLevel: riskLevel,
            createdAt: createdAt,
            profileID: profileID
        )
    }

    private func decodeCustomAllergen(from data: [String: Any], profileID: UUID) -> CustomAllergenRecord? {
        guard let id = data["id"] as? String,
              let name = data["name"] as? String,
              let createdAt = (data["createdAt"] as? Timestamp)?.dateValue()
        else {
            return nil
        }
        let aliases = data["aliases"] as? [String] ?? [name.lowercased()]
        return CustomAllergenRecord(id: id, name: name, aliases: aliases, profileID: profileID, createdAt: createdAt)
    }

    private func deleteAllDocuments(in collection: CollectionReference) async {
        do {
            let snapshot = try await collection.getDocuments()
            for doc in snapshot.documents {
                try? await doc.reference.delete()
            }
        } catch {
            print("[Sync] cascade delete failed: \(error.localizedDescription)")
        }
    }
}
