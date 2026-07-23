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
        
        let now = ISO8601DateFormatter().string(from: Date())
        let captured = [CapturedTarget(id: "credentials", type: "file", captured: true, required: true, error: nil)]
        
        let manifest = ProfileManifest(
            id: resolvedId,
            version: 1,
            name: name,
            createdAt: matchingExisting?.createdAt ?? now,
            updatedAt: now,
            account: accountState,
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
        
        // Step 1: Backup current credentials
        let nowTimestamp = Int(Date().timeIntervalSince1970 * 1000)
        let backupDir = backupsRoot.appendingPathComponent("before-\(id)-\(nowTimestamp)")
        let backupDataDir = backupDir.appendingPathComponent("data/credentials")
        try fm.createDirectory(at: backupDataDir, withIntermediateDirectories: true)
        
        if fm.fileExists(atPath: credentialsFile.path) {
            let backupFile = backupDataDir.appendingPathComponent("credentials.json")
            try fm.copyItem(at: credentialsFile, to: backupFile)
        }
        
        // Step 2: Overwrite credentials.json
        let destDir = credentialsFile.deletingLastPathComponent()
        try fm.createDirectory(at: destDir, withIntermediateDirectories: true)
        
        if fm.fileExists(atPath: credentialsFile.path) {
            try fm.removeItem(at: credentialsFile)
        }
        try fm.copyItem(at: targetCredentialsSnapshot, to: credentialsFile)
    }
    
    static func deleteProfile(id: String) throws {
        let fm = FileManager.default
        let profileDir = profilesRoot.appendingPathComponent(id)
        if fm.fileExists(atPath: profileDir.path) {
            try fm.removeItem(at: profileDir)
        }
    }
}
