import Foundation

/// Where the plaintext originals live on this device.
///
/// **A cache with a promise.** The durable copy of a photo is the encrypted
/// object in Cloud Storage; the file here is the readable one, and it can be
/// deleted at any time — by eviction, or by the person themselves — because it
/// can always be fetched and opened again. That is what makes it safe to hand
/// the folder to the user in the Files app.
///
/// Two deliberate choices about where it sits:
///
///  * **`Documents/Photos`, not Application Support.** With
///    `UIFileSharingEnabled` and `LSSupportsOpeningDocumentsInPlace`, a folder
///    in Documents appears in the iOS Files app under Pacelli. Drag them out,
///    back them up, delete them. "Stored locally so you have full control"
///    should mean something you can actually open.
///  * **Excluded from iCloud backup.** This is the only readable copy of your
///    photos anywhere, and Pacelli's whole posture is that readable content
///    does not leave your devices. The encrypted object is already a durable
///    backup and nobody but a household member can open it.
enum PhotoStore {

    private static var fm: FileManager { .default }

    static func householdDirectory(_ householdId: String) throws -> URL {
        let docs = try fm.url(
            for: .documentDirectory, in: .userDomainMask,
            appropriateFor: nil, create: true)
        var dir = docs
            .appendingPathComponent("Photos", isDirectory: true)
            .appendingPathComponent(householdId, isDirectory: true)

        if !fm.fileExists(atPath: dir.path) {
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            try? dir.setResourceValues(values)
        }
        return dir
    }

    static func url(householdId: String, photoId: String) throws -> URL {
        try householdDirectory(householdId).appendingPathComponent("\(photoId).jpg")
    }

    static func has(householdId: String, photoId: String) -> Bool {
        guard let u = try? url(householdId: householdId, photoId: photoId) else {
            return false
        }
        return fm.fileExists(atPath: u.path)
    }

    static func read(householdId: String, photoId: String) -> Data? {
        guard let u = try? url(householdId: householdId, photoId: photoId) else {
            return nil
        }
        return try? Data(contentsOf: u)
    }

    @discardableResult
    static func write(_ jpeg: Data, householdId: String, photoId: String) throws -> URL {
        let u = try url(householdId: householdId, photoId: photoId)
        try jpeg.write(to: u, options: .atomic)
        return u
    }

    static func delete(householdId: String, photoId: String) {
        guard let u = try? url(householdId: householdId, photoId: photoId) else { return }
        try? fm.removeItem(at: u)
    }

    /// Everything for one household, used by burn and by "switch household".
    static func deleteAll(householdId: String) {
        guard let dir = try? householdDirectory(householdId) else { return }
        try? fm.removeItem(at: dir)
    }

    /// Every photo directory this device holds. Burn takes the lot, because a
    /// device can have been in more than one household.
    static func deleteEverything() {
        guard let docs = try? fm.url(
            for: .documentDirectory, in: .userDomainMask,
            appropriateFor: nil, create: false)
        else { return }
        try? fm.removeItem(at: docs.appendingPathComponent("Photos", isDirectory: true))
    }

    // MARK: - Housekeeping

    /// Bytes held locally for one household.
    static func bytesUsed(householdId: String) -> Int64 {
        guard let dir = try? householdDirectory(householdId),
              let files = try? fm.contentsOfDirectory(
                at: dir, includingPropertiesForKeys: [.fileSizeKey])
        else { return 0 }
        return files.reduce(0) { total, url in
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            return total + Int64(size)
        }
    }

    /// Removes local files with no surviving photo document.
    ///
    /// Self-healing rather than transactional: a delete that raced an app kill,
    /// or a household this device left, leaves readable pictures on disk that
    /// nothing will ever show. Reconciling at launch is cheaper and more
    /// reliable than trying to make two stores agree at the moment of deletion.
    static func reconcile(householdId: String, keeping liveIds: Set<String>) {
        guard let dir = try? householdDirectory(householdId),
              let files = try? fm.contentsOfDirectory(atPath: dir.path)
        else { return }
        for name in files where name.hasSuffix(".jpg") {
            let id = String(name.dropLast(4))
            if !liveIds.contains(id) {
                try? fm.removeItem(at: dir.appendingPathComponent(name))
            }
        }
    }

    /// Frees space by dropping the least recently opened originals first.
    ///
    /// Two floors, both of which exist because the obvious implementation
    /// would lose data or annoy someone:
    ///
    ///  * a photo whose upload has not finished is the ONLY copy in existence
    ///    and is never evicted, whatever its age;
    ///  * a photo attached to something due in the next week is what the person
    ///    is about to need, so it stays too.
    static func evict(
        householdId: String, downTo budget: Int64,
        protecting protectedIds: Set<String>
    ) {
        guard bytesUsed(householdId: householdId) > budget,
              let dir = try? householdDirectory(householdId),
              let files = try? fm.contentsOfDirectory(
                at: dir,
                includingPropertiesForKeys: [.contentAccessDateKey, .fileSizeKey])
        else { return }

        let candidates = files
            .filter { !protectedIds.contains(String($0.lastPathComponent.dropLast(4))) }
            .sorted { a, b in
                let da = (try? a.resourceValues(forKeys: [.contentAccessDateKey])
                    .contentAccessDate) ?? .distantPast
                let db = (try? b.resourceValues(forKeys: [.contentAccessDateKey])
                    .contentAccessDate) ?? .distantPast
                return da < db
            }

        var used = bytesUsed(householdId: householdId)
        for url in candidates where used > budget {
            let size = Int64((try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
            try? fm.removeItem(at: url)
            used -= size
        }
    }
}
