import Combine
import CoreData
import Foundation

@MainActor
final class PersistenceStore: ObservableObject {
    @Published private(set) var isLoaded = false
    @Published var isInitialSyncInProgress = false
    @Published private(set) var profiles: [UserProfile] = []
    @Published private(set) var activeProfileID: UUID?
    @Published private(set) var scanHistory: [ScanRecord] = []
    @Published private(set) var securitySettings: SecuritySettings = .default
    @Published private(set) var customAllergens: [Allergen] = []

    private let activeProfileKey = "AllerScan.activeProfileID"

    /// Set by AllerScanApp after init. PersistenceStore calls into this on every mutation
    /// so changes propagate to Firestore. Optional so the store can run without sync (tests, offline).
    var syncService: SyncService?

    var activeProfile: UserProfile? {
        guard let id = activeProfileID else { return profiles.first }
        return profiles.first { $0.id == id } ?? profiles.first
    }

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "AllerScanModel", managedObjectModel: Self.makeModel())

        if inMemory {
            let description = NSPersistentStoreDescription()
            description.url = URL(fileURLWithPath: "/dev/null")
            container.persistentStoreDescriptions = [description]
        } else {
            container.persistentStoreDescriptions.forEach { description in
                description.shouldMigrateStoreAutomatically = true
                description.shouldInferMappingModelAutomatically = true
            }
        }

        loadPersistentStores(inMemory: inMemory)
    }

    private func loadPersistentStores(inMemory: Bool, didRetryAfterReset: Bool = false) {
        container.loadPersistentStores { [weak self] description, error in
            guard let self else { return }

            if let error {
                guard !inMemory, !didRetryAfterReset else {
                    fatalError("Unable to load persistent store: \(error.localizedDescription)")
                }

                self.resetPersistentStore(at: description.url)
                self.loadPersistentStores(inMemory: inMemory, didRetryAfterReset: true)
                return
            }

            Task { @MainActor in
                self.container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
                self.refresh()
                self.isLoaded = true
            }
        }
    }

    private func resetPersistentStore(at url: URL?) {
        guard let url else { return }
        let coordinator = container.persistentStoreCoordinator

        try? coordinator.destroyPersistentStore(at: url, type: .sqlite)

        let walURL = url.appendingPathExtension("wal")
        let shmURL = url.appendingPathExtension("shm")
        try? FileManager.default.removeItem(at: url)
        try? FileManager.default.removeItem(at: walURL)
        try? FileManager.default.removeItem(at: shmURL)
    }

    func refresh() {
        profiles = fetchAllProfiles()
        activeProfileID = loadActiveProfileID() ?? profiles.first?.id
        scanHistory = fetchHistory()
        securitySettings = fetchSecuritySettings()
        customAllergens = fetchCustomAllergens()
    }

    func saveProfile(_ profile: UserProfile) throws {
        let context = container.viewContext
        let request = UserProfileEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", profile.id as CVarArg)
        let isNewProfile = (try? context.fetch(request).first) == nil
        let entity = (try? context.fetch(request).first) ?? UserProfileEntity(context: context)
        entity.id = profile.id
        entity.name = profile.name
        entity.trackedAllergenIDs = encode(profile.trackedAllergenIDs)
        entity.createdAt = profile.createdAt

        // If this is a brand-new profile, claim any custom allergens that were added
        // during initial onboarding (those have profileID = nil because no profile existed yet).
        if isNewProfile {
            claimOrphanedCustomAllergens(forProfile: profile.id, in: context)
        }

        try context.save()
        refresh()
        syncService?.upload(profile: profile)
    }

    private func claimOrphanedCustomAllergens(forProfile profileID: UUID, in context: NSManagedObjectContext) {
        let request = CustomAllergenEntity.fetchRequest()
        request.predicate = NSPredicate(format: "profileID == nil")
        guard let orphans = try? context.fetch(request) else { return }
        for orphan in orphans {
            orphan.profileID = profileID
            // Push the now-claimed allergen to Firestore under the new profile.
            if let id = orphan.id, let name = orphan.name {
                let aliases = decode([String].self, from: orphan.aliases) ?? [name.lowercased()]
                let allergen = Allergen(id: id, name: name, aliases: aliases, hiddenAliases: [], negativeContexts: [])
                syncService?.upload(customAllergen: allergen, profileID: profileID)
            }
        }
    }

    func deleteProfile(id: UUID) throws {
        let context = container.viewContext

        // Cascade delete scans + custom allergens for this profile.
        cascadeDeleteEntities(entityName: "ScanRecordEntity", profileID: id, in: context)
        cascadeDeleteEntities(entityName: "CustomAllergenEntity", profileID: id, in: context)

        let request = UserProfileEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        if let entity = try? context.fetch(request).first {
            context.delete(entity)
        }
        try context.save()

        if activeProfileID == id {
            activeProfileID = nil
            UserDefaults.standard.removeObject(forKey: activeProfileKey)
        }

        refresh()
        syncService?.deleteProfile(id: id)
    }

    func setActiveProfile(id: UUID) {
        guard profiles.contains(where: { $0.id == id }) else { return }
        activeProfileID = id
        UserDefaults.standard.set(id.uuidString, forKey: activeProfileKey)
        // Re-fetch scan history + custom allergens for the new profile.
        scanHistory = fetchHistory()
        customAllergens = fetchCustomAllergens()
    }

    private func cascadeDeleteEntities(entityName: String, profileID: UUID, in context: NSManagedObjectContext) {
        let request = NSFetchRequest<NSManagedObject>(entityName: entityName)
        request.predicate = NSPredicate(format: "profileID == %@", profileID as CVarArg)
        if let entities = try? context.fetch(request) {
            for entity in entities { context.delete(entity) }
        }
    }

    /// Replace local profile/scan/custom-allergen data with a remote snapshot from Firestore.
    /// Used after sign-in to restore the user's data on a new device.
    func applyRemoteSnapshot(_ snapshot: SyncService.RemoteSnapshot) throws {
        let context = container.viewContext

        wipeAllSyncableEntities(in: context)

        for profile in snapshot.profiles {
            let entity = UserProfileEntity(context: context)
            entity.id = profile.id
            entity.name = profile.name
            entity.trackedAllergenIDs = encode(profile.trackedAllergenIDs)
            entity.createdAt = profile.createdAt
        }

        for (profileID, scans) in snapshot.scansByProfile {
            for scan in scans {
                let entity = ScanRecordEntity(context: context)
                entity.id = scan.id
                entity.rawText = scan.rawText
                entity.normalizedText = scan.normalizedText
                entity.foundIngredientsText = scan.foundIngredientsText
                entity.matches = encode(scan.matches)
                entity.riskLevel = scan.riskLevel.rawValue
                entity.createdAt = scan.createdAt
                entity.profileID = profileID
            }
        }

        for (profileID, customs) in snapshot.customAllergensByProfile {
            for custom in customs {
                let entity = CustomAllergenEntity(context: context)
                entity.id = custom.id
                entity.name = custom.name
                entity.aliases = encode(custom.aliases)
                entity.createdAt = custom.createdAt
                entity.profileID = profileID
            }
        }

        try context.save()
        refresh()
    }

    /// Wipe all syncable local data on sign-out so the next user doesn't see the previous one's data.
    func clearSyncableLocalData() {
        let context = container.viewContext
        wipeAllSyncableEntities(in: context)
        try? context.save()
        UserDefaults.standard.removeObject(forKey: activeProfileKey)
        activeProfileID = nil
        refresh()
    }

    private func wipeAllSyncableEntities(in context: NSManagedObjectContext) {
        for name in ["UserProfileEntity", "ScanRecordEntity", "CustomAllergenEntity"] {
            let request = NSFetchRequest<NSManagedObject>(entityName: name)
            if let entities = try? context.fetch(request) {
                for entity in entities { context.delete(entity) }
            }
        }
    }

    private func loadActiveProfileID() -> UUID? {
        guard let raw = UserDefaults.standard.string(forKey: activeProfileKey) else { return nil }
        return UUID(uuidString: raw)
    }

    func saveScanRecord(_ record: ScanRecord) throws {
        let context = container.viewContext
        let entity = ScanRecordEntity(context: context)
        let stamped = record.with(profileID: activeProfileID)
        entity.id = stamped.id
        entity.rawText = stamped.rawText
        entity.normalizedText = stamped.normalizedText
        entity.foundIngredientsText = stamped.foundIngredientsText
        entity.matches = encode(stamped.matches)
        entity.riskLevel = stamped.riskLevel.rawValue
        entity.createdAt = stamped.createdAt
        entity.profileID = stamped.profileID
        try context.save()
        refresh()
        if let profileID = stamped.profileID {
            syncService?.upload(scan: stamped, profileID: profileID)
        }
    }

    func deleteScanRecords(at offsets: IndexSet) throws {
        let context = container.viewContext
        var deletedIDs: [UUID] = []
        let pid = activeProfileID
        for index in offsets {
            let record = scanHistory[index]
            let request = ScanRecordEntity.fetchRequest()
            request.fetchLimit = 1
            request.predicate = NSPredicate(format: "id == %@", record.id as CVarArg)
            if let entity = try context.fetch(request).first {
                context.delete(entity)
                deletedIDs.append(record.id)
            }
        }
        try context.save()
        refresh()
        if let pid {
            for id in deletedIDs { syncService?.deleteScan(id: id, profileID: pid) }
        }
    }

    func saveCustomAllergen(_ allergen: Allergen) throws {
        let context = container.viewContext
        let entity = CustomAllergenEntity(context: context)
        entity.id = allergen.id
        entity.name = allergen.name
        entity.aliases = encode(allergen.aliases)
        entity.createdAt = Date.now
        entity.profileID = activeProfileID
        try context.save()
        refresh()
        if let pid = activeProfileID {
            syncService?.upload(customAllergen: allergen, profileID: pid)
        }
    }

    func deleteCustomAllergen(id: String) throws {
        let context = container.viewContext
        let request = CustomAllergenEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id)
        let pid = activeProfileID
        if let entity = try context.fetch(request).first {
            context.delete(entity)
            try context.save()
            refresh()
            if let pid {
                syncService?.deleteCustomAllergen(id: id, profileID: pid)
            }
        }
    }

    func updateSecuritySettings(_ settings: SecuritySettings) throws {
        let context = container.viewContext
        let request = AppSettingsEntity.fetchRequest()
        let entity = (try? context.fetch(request).first) ?? AppSettingsEntity(context: context)
        entity.id = entity.id ?? UUID()
        entity.isBiometricLockEnabled = settings.isBiometricLockEnabled
        entity.notificationsEnabled = settings.notificationsEnabled
        entity.reminderHour = Int16(settings.reminderHour)
        entity.reminderMinute = Int16(settings.reminderMinute)
        entity.emergencyContactName = settings.emergencyContact.name
        entity.emergencyContactPhone = settings.emergencyContact.phoneNumber
        try context.save()
        refresh()
    }

    private func fetchAllProfiles() -> [UserProfile] {
        let request = UserProfileEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \UserProfileEntity.createdAt, ascending: true)]
        let entities = (try? container.viewContext.fetch(request)) ?? []
        return entities.compactMap { entity in
            guard let id = entity.id,
                  let name = entity.name,
                  let createdAt = entity.createdAt
            else {
                return nil
            }
            return UserProfile(
                id: id,
                name: name,
                trackedAllergenIDs: decode([String].self, from: entity.trackedAllergenIDs) ?? [],
                createdAt: createdAt
            )
        }
    }

    private func fetchHistory() -> [ScanRecord] {
        let request = ScanRecordEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \ScanRecordEntity.createdAt, ascending: false)]
        if let active = activeProfileID {
            request.predicate = NSPredicate(format: "profileID == %@", active as CVarArg)
        }
        let entities = (try? container.viewContext.fetch(request)) ?? []
        return entities.compactMap { entity in
            guard let id = entity.id,
                  let rawText = entity.rawText,
                  let normalizedText = entity.normalizedText,
                  let riskLevelRaw = entity.riskLevel,
                  let riskLevel = RiskLevel(rawValue: riskLevelRaw),
                  let createdAt = entity.createdAt
            else {
                return nil
            }

            return ScanRecord(
                id: id,
                rawText: rawText,
                normalizedText: normalizedText,
                foundIngredientsText: entity.foundIngredientsText ?? rawText,
                matches: decode([DetectedAllergen].self, from: entity.matches) ?? [],
                riskLevel: riskLevel,
                createdAt: createdAt,
                profileID: entity.profileID
            )
        }
    }

    private func fetchCustomAllergens() -> [Allergen] {
        let request = CustomAllergenEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \CustomAllergenEntity.createdAt, ascending: true)]
        if let active = activeProfileID {
            request.predicate = NSPredicate(format: "profileID == %@", active as CVarArg)
        }
        let entities = (try? container.viewContext.fetch(request)) ?? []
        return entities.compactMap { entity in
            guard let id = entity.id, let name = entity.name else { return nil }
            let aliases = decode([String].self, from: entity.aliases) ?? [name.lowercased()]
            return Allergen(id: id, name: name, aliases: aliases, hiddenAliases: [], negativeContexts: [])
        }
    }

    private func fetchSecuritySettings() -> SecuritySettings {
        let request = AppSettingsEntity.fetchRequest()
        request.fetchLimit = 1
        guard let entity = try? container.viewContext.fetch(request).first else {
            return .default
        }

        return SecuritySettings(
            isBiometricLockEnabled: entity.isBiometricLockEnabled,
            notificationsEnabled: entity.notificationsEnabled,
            reminderHour: Int(entity.reminderHour),
            reminderMinute: Int(entity.reminderMinute),
            emergencyContact: EmergencyContact(
                name: entity.emergencyContactName ?? "",
                phoneNumber: entity.emergencyContactPhone ?? ""
            )
        )
    }

    private func encode<T: Encodable>(_ value: T) -> Data? {
        try? JSONEncoder().encode(value)
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data?) -> T? {
        guard let data else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}

extension PersistenceStore {
    static func makeModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()

        let userProfile = NSEntityDescription()
        userProfile.name = "UserProfileEntity"
        userProfile.managedObjectClassName = NSStringFromClass(UserProfileEntity.self)
        userProfile.properties = [
            attribute("id", type: .UUIDAttributeType),
            attribute("name", type: .stringAttributeType),
            attribute("trackedAllergenIDs", type: .binaryDataAttributeType, optional: true),
            attribute("createdAt", type: .dateAttributeType)
        ]

        let scanRecord = NSEntityDescription()
        scanRecord.name = "ScanRecordEntity"
        scanRecord.managedObjectClassName = NSStringFromClass(ScanRecordEntity.self)
        scanRecord.properties = [
            attribute("id", type: .UUIDAttributeType),
            attribute("rawText", type: .stringAttributeType),
            attribute("normalizedText", type: .stringAttributeType),
            attribute("foundIngredientsText", type: .stringAttributeType, optional: true),
            attribute("matches", type: .binaryDataAttributeType, optional: true),
            attribute("riskLevel", type: .stringAttributeType),
            attribute("createdAt", type: .dateAttributeType),
            attribute("profileID", type: .UUIDAttributeType, optional: true)
        ]

        let appSettings = NSEntityDescription()
        appSettings.name = "AppSettingsEntity"
        appSettings.managedObjectClassName = NSStringFromClass(AppSettingsEntity.self)
        appSettings.properties = [
            attribute("id", type: .UUIDAttributeType),
            attribute("isBiometricLockEnabled", type: .booleanAttributeType),
            attribute("notificationsEnabled", type: .booleanAttributeType),
            attribute("reminderHour", type: .integer16AttributeType),
            attribute("reminderMinute", type: .integer16AttributeType),
            attribute("emergencyContactName", type: .stringAttributeType, optional: true),
            attribute("emergencyContactPhone", type: .stringAttributeType, optional: true)
        ]

        let customAllergen = NSEntityDescription()
        customAllergen.name = "CustomAllergenEntity"
        customAllergen.managedObjectClassName = NSStringFromClass(CustomAllergenEntity.self)
        customAllergen.properties = [
            attribute("id", type: .stringAttributeType),
            attribute("name", type: .stringAttributeType),
            attribute("aliases", type: .binaryDataAttributeType, optional: true),
            attribute("createdAt", type: .dateAttributeType),
            attribute("profileID", type: .UUIDAttributeType, optional: true)
        ]

        model.entities = [userProfile, scanRecord, appSettings, customAllergen]
        return model
    }

    private static func attribute(
        _ name: String,
        type: NSAttributeType,
        optional: Bool = false
    ) -> NSAttributeDescription {
        let attribute = NSAttributeDescription()
        attribute.name = name
        attribute.attributeType = type
        attribute.isOptional = optional
        return attribute
    }
}

@objc(UserProfileEntity)
final class UserProfileEntity: NSManagedObject {
    @NSManaged var id: UUID?
    @NSManaged var name: String?
    @NSManaged var trackedAllergenIDs: Data?
    @NSManaged var createdAt: Date?

    @nonobjc class func fetchRequest() -> NSFetchRequest<UserProfileEntity> {
        NSFetchRequest<UserProfileEntity>(entityName: "UserProfileEntity")
    }
}

@objc(ScanRecordEntity)
final class ScanRecordEntity: NSManagedObject {
    @NSManaged var id: UUID?
    @NSManaged var rawText: String?
    @NSManaged var normalizedText: String?
    @NSManaged var foundIngredientsText: String?
    @NSManaged var matches: Data?
    @NSManaged var riskLevel: String?
    @NSManaged var createdAt: Date?
    @NSManaged var profileID: UUID?

    @nonobjc class func fetchRequest() -> NSFetchRequest<ScanRecordEntity> {
        NSFetchRequest<ScanRecordEntity>(entityName: "ScanRecordEntity")
    }
}

@objc(CustomAllergenEntity)
final class CustomAllergenEntity: NSManagedObject {
    @NSManaged var id: String?
    @NSManaged var name: String?
    @NSManaged var aliases: Data?
    @NSManaged var createdAt: Date?
    @NSManaged var profileID: UUID?

    @nonobjc class func fetchRequest() -> NSFetchRequest<CustomAllergenEntity> {
        NSFetchRequest<CustomAllergenEntity>(entityName: "CustomAllergenEntity")
    }
}

@objc(AppSettingsEntity)
final class AppSettingsEntity: NSManagedObject {
    @NSManaged var id: UUID?
    @NSManaged var isBiometricLockEnabled: Bool
    @NSManaged var notificationsEnabled: Bool
    @NSManaged var reminderHour: Int16
    @NSManaged var reminderMinute: Int16
    @NSManaged var emergencyContactName: String?
    @NSManaged var emergencyContactPhone: String?

    @nonobjc class func fetchRequest() -> NSFetchRequest<AppSettingsEntity> {
        NSFetchRequest<AppSettingsEntity>(entityName: "AppSettingsEntity")
    }
}
