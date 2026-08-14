import CryptoKit
import Foundation

actor UsageStore {
    private let fileURL: URL
    private var records: [UsageRecord] = []

    init(fileURL: URL? = nil) {
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appending(path: "KeylumeClone", directoryHint: .isDirectory)
            self.fileURL = base.appending(path: "usage.json")
        }
    }

    func load() throws -> [UsageRecord] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            records = []
            return records
        }
        records = try JSONDecoder().decode([UsageRecord].self, from: Data(contentsOf: fileURL))
        return records
    }

    func append(_ record: UsageRecord) throws -> [UsageRecord] {
        records.append(record)
        try persist()
        return records
    }

    private func persist() throws {
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(records).write(to: fileURL, options: .atomic)
    }
}

enum LicenseState: Equatable {
    case trial(daysRemaining: Int)
    case licensed
    case expired

    var menuLabel: String {
        switch self {
        case .trial(let days): "\(days) days remaining"
        case .licensed: "Licensed"
        case .expired: "Trial expired"
        }
    }
}

@MainActor
@Observable
final class LicenseManager {
    private enum Key {
        static let trialStart = "candidateTrialStart"
        static let license = "candidateLicense"
    }

    private let defaults: UserDefaults
    var state: LicenseState = .trial(daysRemaining: 14)
    var activationError: String?

    init(defaults: UserDefaults = .standard, now: Date = .now) {
        self.defaults = defaults
        if defaults.object(forKey: Key.trialStart) == nil {
            defaults.set(now, forKey: Key.trialStart)
        }
        refresh(now: now)
    }

    func refresh(now: Date = .now) {
        if let key = defaults.string(forKey: Key.license), Self.isValidCandidateKey(key) {
            state = .licensed
            return
        }
        let start = defaults.object(forKey: Key.trialStart) as? Date ?? now
        let elapsed = max(0, Calendar.current.dateComponents([.day], from: start, to: now).day ?? 0)
        let remaining = max(0, 14 - elapsed)
        state = remaining > 0 ? .trial(daysRemaining: remaining) : .expired
    }

    func activate(_ key: String) -> Bool {
        let normalized = key.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard Self.isValidCandidateKey(normalized) else {
            activationError = "Invalid license key."
            return false
        }
        defaults.set(normalized, forKey: Key.license)
        activationError = nil
        state = .licensed
        return true
    }

    func deactivate() {
        defaults.removeObject(forKey: Key.license)
        activationError = nil
        refresh()
    }

    static func isValidCandidateKey(_ key: String) -> Bool {
        let groups = key.uppercased().split(separator: "-").map(String.init)
        guard groups.count == 4, groups[0] == "KEYLUME", groups.dropFirst().allSatisfy({ $0.count == 4 }) else { return false }
        let payload = groups[1] + groups[2]
        let digest = SHA256.hash(data: Data(payload.utf8))
        let expected = digest.prefix(2).map { String(format: "%02X", $0) }.joined()
        return groups[3] == expected
    }
}

struct UpdateStatus: Equatable {
    let currentVersion: String
    let latestVersion: String
    let downloadURL: URL?
    var updateAvailable: Bool { latestVersion.compare(currentVersion, options: .numeric) == .orderedDescending }
}

struct UpdateChecker {
    struct Manifest: Decodable { let version: String; let downloadURL: URL? }

    let session: URLSession
    let feedURL: URL?

    init(session: URLSession = .shared, feedURL: URL? = ProcessInfo.processInfo.environment["KEYLUME_CLONE_UPDATE_FEED"].flatMap(URL.init(string:))) {
        self.session = session
        self.feedURL = feedURL
    }

    func check(currentVersion: String) async throws -> UpdateStatus {
        guard let feedURL else {
            return UpdateStatus(currentVersion: currentVersion, latestVersion: currentVersion, downloadURL: nil)
        }
        let (data, response) = try await session.data(from: feedURL)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        let manifest = try JSONDecoder().decode(Manifest.self, from: data)
        return UpdateStatus(currentVersion: currentVersion, latestVersion: manifest.version, downloadURL: manifest.downloadURL)
    }
}
