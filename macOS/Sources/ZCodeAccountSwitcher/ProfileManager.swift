import Foundation
import CryptoKit

struct ProfileManager {
    static var appSupportDirectory: URL {
        let paths = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        return paths[0].appendingPathComponent("zcode-account-switcher")
    }
    
    static var profilesRoot: URL {
        return appSupportDirectory.appendingPathComponent("profiles")
    }
    
    static var backupsRoot: URL {
        return appSupportDirectory.appendingPathComponent("switch-backups")
    }
    
    static var credentialsFile: URL {
        return URL(fileURLWithPath: (NSHomeDirectory() as NSString).appendingPathComponent(".zcode/v2/credentials.json"))
    }

    /// config.json holds plaintext per-provider apiKeys (e.g. builtin:bigmodel),
    /// a SECOND account-identity store independent of the encrypted credentials.json.
    /// If not captured/restored alongside credentials.json, requests keep hitting
    /// the OLD account's apiKey after a switch.
    static var configFile: URL {
        return URL(fileURLWithPath: (NSHomeDirectory() as NSString).appendingPathComponent(".zcode/v2/config.json"))
    }
    
    static func maskIdentity(_ value: String?) -> String? {
        guard let text = value?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else {
            return nil
        }
        if text.contains("@") {
            let parts = text.components(separatedBy: "@")
            let name = parts[0]
            let domain = parts[1]
            let prefix = name.prefix(2)
            return "\(prefix)***@\(domain)"
        }
        if text.range(of: "^\\d{7,}$", options: .regularExpression) != nil {
            let prefix = text.prefix(3)
            let suffix = text.suffix(4)
            return "\(prefix)****\(suffix)"
        }
        if text.count > 8 {
            let prefix = text.prefix(4)
            let suffix = text.suffix(4)
            return "\(prefix)...\(suffix)"
        }
        return text
    }
    
    static func parseUserProfile(provider: String, jsonString: String?) -> UserProfile? {
        guard let jsonString = jsonString,
              let data = jsonString.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        let displayName = (dict["displayName"] as? String) ?? (dict["name"] as? String) ?? (dict["nickname"] as? String) ?? (dict["username"] as? String) ?? (dict["email"] as? String) ?? (dict["phone"] as? String)
        let username = (dict["username"] as? String) ?? (dict["email"] as? String) ?? (dict["phone"] as? String) ?? (dict["id"] as? String)
        let idStr: String? = {
            if let id = dict["id"] as? String { return id }
            if let id = dict["id"] as? CustomStringConvertible { return String(describing: id) }
            if let userId = dict["userId"] as? CustomStringConvertible { return String(describing: userId) }
            return nil
        }()
        let avatarUrl = (dict["avatarUrl"] as? String) ?? (dict["avatar"] as? String)
        let rawIdent = (dict["email"] as? String) ?? (dict["phone"] as? String) ?? (dict["username"] as? String) ?? idStr
        let masked = maskIdentity(rawIdent)
        
        return UserProfile(
            provider: provider,
            id: idStr,
            username: username,
            displayName: displayName,
            avatarUrl: avatarUrl,
            identityMasked: masked
        )
    }
    
    static func readCurrentAccountState() -> AccountState {
        guard let credentials = CredentialDecryptor.readPlainCredentials() else {
            return AccountState(authenticated: false, activeProvider: "bigmodel", profile: nil, displayName: "未检测到凭据", stableId: "none")
        }
        
        let activeProvider = credentials["oauth:active_provider"] ?? "bigmodel"
        let bigmodelProfile = parseUserProfile(provider: "bigmodel", jsonString: credentials["oauth:bigmodel:user_info"])
        let zaiProfile = parseUserProfile(provider: "zai", jsonString: credentials["oauth:zai:user_info"])
        
        let profiles = [bigmodelProfile, zaiProfile].compactMap { $0 }
        let active = profiles.first(where: { $0.provider == activeProvider }) ?? profiles.first
        
        let authenticated = active != nil
        let displayName = active?.displayName ?? active?.username ?? active?.id ?? "未知 ZCode 账号"
        let stableId = "\(activeProvider):\(active?.id ?? active?.username ?? credentials["zcodefeedbackclientid"] ?? "unknown")"
        
        return AccountState(
            authenticated: authenticated,
            activeProvider: activeProvider,
            profile: active,
            displayName: displayName,
            stableId: stableId
        )
    }

    static func fetchCurrentAccountQuota() async -> QuotaSnapshot {
        let plainCredentials = CredentialDecryptor.readPlainCredentials()
        let configData = try? Data(contentsOf: configFile)
        return await QuotaFetcher.fetchQuota(credentials: plainCredentials, configData: configData)
    }

    static func fetchProfileQuota(profileId: String) async -> QuotaSnapshot {
        let profileDir = profilesRoot.appendingPathComponent(profileId)
        let credentialsSnapshot = profileDir.appendingPathComponent("data/credentials/credentials.json")
        let configEnc = profileDir.appendingPathComponent("data/credentials/config.json.enc")
        let configLegacy = profileDir.appendingPathComponent("data/credentials/config.json")

        var plainCredentials: [String: String]? = nil
        if let rawData = try? Data(contentsOf: credentialsSnapshot) {
            plainCredentials = CredentialDecryptor.parsePlainCredentials(data: rawData)
        }

        var configData: Data? = nil
        if let encStr = try? String(contentsOf: configEnc, encoding: .utf8),
           let decData = CredentialDecryptor.decryptToData(encStr) {
            configData = decData
        } else if let legacyData = try? Data(contentsOf: configLegacy) {
            configData = legacyData
        } else {
            configData = try? Data(contentsOf: configFile)
        }

        return await QuotaFetcher.fetchQuota(credentials: plainCredentials, configData: configData)
    }
    
    static func safeId(name: String, stablePart: String) -> String {
        let cleaned = name.lowercased()
            .replacingOccurrences(of: "[^a-z0-9\\u4e00-\\u9fa5_-]+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        
        let suffixData = Data((stablePart.isEmpty ? String(Date().timeIntervalSince1970) : stablePart).utf8)
        let hash = SHA256.hash(data: suffixData)
        let suffix = hash.compactMap { String(format: "%02x", $0) }.joined().prefix(8)
        let base = cleaned.isEmpty ? "profile" : cleaned
        return "\(base)-\(suffix)"
    }
    
    static func listProfiles() -> [ProfileManifest] {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(at: profilesRoot, includingPropertiesForKeys: [.isDirectoryKey], options: .skipsHiddenFiles) else {
            return []
        }
        
        var profiles: [ProfileManifest] = []
        let decoder = JSONDecoder()
        
        for dir in entries {
            var isDir: ObjCBool = false
            if fm.fileExists(atPath: dir.path, isDirectory: &isDir), isDir.boolValue {
                let manifestURL = dir.appendingPathComponent("manifest.json")
                if let data = try? Data(contentsOf: manifestURL),
                   var manifest = try? decoder.decode(ProfileManifest.self, from: data) {
                    manifest.id = dir.lastPathComponent
                    profiles.append(manifest)
                }
            }
        }
        
        profiles.sort { a, b in
            return a.updatedAt > b.updatedAt
        }
        
        var seenStableIds = Set<String>()
        var uniqueProfiles: [ProfileManifest] = []
        for p in profiles {
            let stableId = p.account.stableId
            if !seenStableIds.contains(stableId) {
                seenStableIds.insert(stableId)
                uniqueProfiles.append(p)
            }
        }
        return uniqueProfiles
    }
    
    static func saveCurrentAsProfile(customName: String? = nil, profileId: String? = nil) throws -> ProfileManifest {
        let fm = FileManager.default
        let accountState = readCurrentAccountState()
        guard accountState.authenticated else {
            throw NSError(domain: "ProfileManager", code: 400, userInfo: [NSLocalizedDescriptionKey: "当前未发现有效登录的 ZCode 账号凭据"])
        }
        
        let name = (customName?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 } ?? accountState.displayName
        
        let existingProfiles = listProfiles()
        let matchingExisting = existingProfiles.first(where: { $0.account.stableId == accountState.stableId })
        let resolvedId = profileId ?? matchingExisting?.id ?? safeId(name: name, stablePart: accountState.stableId)
        
        let targetProfileDir = profilesRoot.appendingPathComponent(resolvedId)
        let credentialsDataDir = targetProfileDir.appendingPathComponent("data/credentials")
        try fm.createDirectory(at: credentialsDataDir, withIntermediateDirectories: true)

        let sourceCredentials = credentialsFile
        guard fm.fileExists(atPath: sourceCredentials.path) else {
            throw NSError(domain: "ProfileManager", code: 404, userInfo: [NSLocalizedDescriptionKey: "没有找到 ~/.zcode/v2/credentials.json 凭据文件"])
        }

        let destCredentials = credentialsDataDir.appendingPathComponent("credentials.json")
        if fm.fileExists(atPath: destCredentials.path) {
            try fm.removeItem(at: destCredentials)
        }
        try fm.copyItem(at: sourceCredentials, to: destCredentials)

        // Capture config.json (plaintext per-provider apiKeys) as a second identity store.
        // It is optional: a fresh install may not have it yet, but if present it MUST be
        // restored together with credentials.json or requests will hit the old account.
        // Stored ENCRYPTED (config.json.enc) because it contains plaintext apiKeys —
        // same AES-256-GCM key as ZCode's own credentials, so it only decrypts on this machine.
        var captured: [CapturedTarget] = [
            CapturedTarget(id: "credentials", type: "file", captured: true, required: true, error: nil)
        ]
        if fm.fileExists(atPath: configFile.path) {
            let destConfigEnc = credentialsDataDir.appendingPathComponent("config.json.enc")
            if let plainData = try? Data(contentsOf: configFile),
               let plain = String(data: plainData, encoding: .utf8),
               let enc = CredentialDecryptor.encrypt(plain) {
                try enc.write(to: destConfigEnc, atomically: true, encoding: .utf8)
                captured.append(CapturedTarget(id: "config", type: "file", captured: true, required: false, error: nil))
            } else {
                captured.append(CapturedTarget(id: "config", type: "file", captured: false, required: false, error: "config.json 读取或加密失败"))
            }
        } else {
            captured.append(CapturedTarget(id: "config", type: "file", captured: false, required: false, error: "config.json not found; only credentials.json captured"))
        }

        let now = ISO8601DateFormatter().string(from: Date())
        let manifest = ProfileManifest(
            id: resolvedId,
            version: 1,
            name: name,
            createdAt: matchingExisting?.createdAt ?? now,
            updatedAt: now,
            account: accountState,
            quota: accountState.quota,
            captured: captured,
            snapshotReady: true,
            pendingSnapshot: false
        )
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let manifestData = try encoder.encode(manifest)
        try manifestData.write(to: targetProfileDir.appendingPathComponent("manifest.json"))
        
        return manifest
    }
    
    static func restoreProfile(id: String) throws {
        let fm = FileManager.default
        let profileDir = profilesRoot.appendingPathComponent(id)
        let manifestURL = profileDir.appendingPathComponent("manifest.json")
        guard fm.fileExists(atPath: manifestURL.path) else {
            throw NSError(domain: "ProfileManager", code: 404, userInfo: [NSLocalizedDescriptionKey: "该账号快照不存在或已被删除"])
        }
        
        let targetCredentialsSnapshot = profileDir.appendingPathComponent("data/credentials/credentials.json")
        guard fm.fileExists(atPath: targetCredentialsSnapshot.path) else {
            throw NSError(domain: "ProfileManager", code: 404, userInfo: [NSLocalizedDescriptionKey: "快照凭据文件损坏或丢失"])
        }

        // Encrypted config snapshot (plaintext apiKeys). Falls back to legacy plaintext name.
        let targetConfigEnc = profileDir.appendingPathComponent("data/credentials/config.json.enc")
        let targetConfigLegacy = profileDir.appendingPathComponent("data/credentials/config.json")

        // Step 1: Backup current credentials + config (if present)
        let nowTimestamp = Int(Date().timeIntervalSince1970 * 1000)
        let backupDir = backupsRoot.appendingPathComponent("before-\(id)-\(nowTimestamp)")
        let backupDataDir = backupDir.appendingPathComponent("data/credentials")
        try fm.createDirectory(at: backupDataDir, withIntermediateDirectories: true)

        if fm.fileExists(atPath: credentialsFile.path) {
            let backupFile = backupDataDir.appendingPathComponent("credentials.json")
            try fm.copyItem(at: credentialsFile, to: backupFile)
        }
        if fm.fileExists(atPath: configFile.path) {
            let backupConfig = backupDataDir.appendingPathComponent("config.json")
            try fm.copyItem(at: configFile, to: backupConfig)
        }

        // Step 2: Overwrite credentials.json
        let destDir = credentialsFile.deletingLastPathComponent()
        try fm.createDirectory(at: destDir, withIntermediateDirectories: true)

        if fm.fileExists(atPath: credentialsFile.path) {
            try fm.removeItem(at: credentialsFile)
        }
        try fm.copyItem(at: targetCredentialsSnapshot, to: credentialsFile)

        // Step 3: Overwrite config.json (plaintext apiKeys) if the snapshot captured it.
        // This is the fix for "requests keep hitting the previous account": without restoring
        // config.json, the per-provider apiKey still belongs to the old account.
        // Decrypts config.json.enc on restore (legacy plaintext fallback supported).
        let hasConfigSnapshot = fm.fileExists(atPath: targetConfigEnc.path) || fm.fileExists(atPath: targetConfigLegacy.path)
        if hasConfigSnapshot {
            let configDir = configFile.deletingLastPathComponent()
            try fm.createDirectory(at: configDir, withIntermediateDirectories: true)

            var restoredConfig: Data? = nil
            if fm.fileExists(atPath: targetConfigEnc.path),
               let enc = try? String(contentsOf: targetConfigEnc, encoding: .utf8),
               let plainData = CredentialDecryptor.decryptToData(enc) {
                restoredConfig = plainData
            } else if fm.fileExists(atPath: targetConfigLegacy.path) {
                // Legacy plaintext snapshot (pre-encryption) — migrate as-is.
                restoredConfig = try? Data(contentsOf: targetConfigLegacy)
            }

            if let data = restoredConfig {
                if fm.fileExists(atPath: configFile.path) {
                    try fm.removeItem(at: configFile)
                }
                try data.write(to: configFile, options: .atomic)
            }
        }
    }
    
    static func deleteProfile(id: String) throws {
        let fm = FileManager.default
        let profileDir = profilesRoot.appendingPathComponent(id)
        if fm.fileExists(atPath: profileDir.path) {
            try fm.removeItem(at: profileDir)
        }
    }
}
