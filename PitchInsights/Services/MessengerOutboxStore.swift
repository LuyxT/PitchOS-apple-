import Foundation
import CryptoKit
import Security

enum MessengerOutboxStoreError: LocalizedError {
    case appSupportUnavailable
    case keyDerivationFailed
    case encryptionFailed
    case decryptionFailed
    case serializationFailed

    var errorDescription: String? {
        switch self {
        case .appSupportUnavailable:
            return "Messenger-Speicher ist nicht verfügbar."
        case .keyDerivationFailed:
            return "Outbox-Schlüssel konnte nicht erzeugt werden."
        case .encryptionFailed:
            return "Outbox konnte nicht verschlüsselt werden."
        case .decryptionFailed:
            return "Outbox konnte nicht entschlüsselt werden."
        case .serializationFailed:
            return "Outbox-Datenformat ist ungültig."
        }
    }
}

final class MessengerOutboxStore {
    private let fileManager: FileManager
    private let keychain: KeychainStore
    private let keychainKey = "pitchinsights.messenger.outbox.key"
    private let filename = "outbox.enc"

    init(fileManager: FileManager = .default, keychain: KeychainStore = .shared) {
        self.fileManager = fileManager
        self.keychain = keychain
    }

    func loadItems() throws -> [MessengerOutboxItem] {
        let url = try outboxURL()
        guard fileManager.fileExists(atPath: url.path(percentEncoded: false)) else {
            return []
        }

        let encryptedData = try Data(contentsOf: url)
        guard !encryptedData.isEmpty else { return [] }

        let key = try encryptionKey()
        let sealedBox: AES.GCM.SealedBox
        do {
            sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
        } catch {
            throw MessengerOutboxStoreError.decryptionFailed
        }

        let plainData: Data
        do {
            plainData = try AES.GCM.open(sealedBox, using: key)
        } catch {
            throw MessengerOutboxStoreError.decryptionFailed
        }

        do {
            return try decoder.decode([MessengerOutboxItem].self, from: plainData)
        } catch {
            throw MessengerOutboxStoreError.serializationFailed
        }
    }

    func saveItems(_ items: [MessengerOutboxItem]) throws {
        let data: Data
        do {
            data = try encoder.encode(items)
        } catch {
            throw MessengerOutboxStoreError.serializationFailed
        }

        let key = try encryptionKey()
        let sealed: AES.GCM.SealedBox
        do {
            sealed = try AES.GCM.seal(data, using: key)
        } catch {
            throw MessengerOutboxStoreError.encryptionFailed
        }

        guard let encrypted = sealed.combined else {
            throw MessengerOutboxStoreError.encryptionFailed
        }

        try encrypted.write(to: outboxURL(), options: [.atomic])
    }

    private func outboxURL() throws -> URL {
        guard let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw MessengerOutboxStoreError.appSupportUnavailable
        }
        let root = appSupport
            .appendingPathComponent("PitchInsights", isDirectory: true)
            .appendingPathComponent("Messenger", isDirectory: true)
        if !fileManager.fileExists(atPath: root.path(percentEncoded: false)) {
            try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        }
        return root.appendingPathComponent(filename, isDirectory: false)
    }

    private func encryptionKey() throws -> SymmetricKey {
        if let encoded = keychain.get(keychainKey),
           let raw = Data(base64Encoded: encoded),
           raw.count == 32 {
            return SymmetricKey(data: raw)
        }

        var bytes = [UInt8](repeating: 0, count: 32)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        guard status == errSecSuccess else {
            throw MessengerOutboxStoreError.keyDerivationFailed
        }
        let data = Data(bytes)
        keychain.set(data.base64EncodedString(), forKey: keychainKey)
        return SymmetricKey(data: data)
    }

    private var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
