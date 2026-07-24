import Foundation

enum SidebarTab: String, CaseIterable, Identifiable, Codable {
    case overview = "概览与凭据"
    case profiles = "账号快照"
    
    var id: String { rawValue }
    var iconName: String {
        switch self {
        case .overview: return "person.crop.circle.badge.checkmark"
        case .profiles: return "square.stack.3d.up.fill"
        }
    }
}

struct UserProfile: Codable, Identifiable, Equatable {
    let provider: String?
    let id: String?
    let username: String?
    let displayName: String?
    let avatarUrl: String?
    let identityMasked: String?
    
    var identifier: String {
        id ?? username ?? displayName ?? identityMasked ?? "unknown"
    }
}

public struct QuotaLimitItem: Codable, Identifiable, Equatable {
    public var id: String { key }
    public let key: String
    public let label: String
    public let percentage: Int
    public let resetTime: String?
    public let colorName: String

    public init(key: String, label: String, percentage: Int, resetTime: String?, colorName: String) {
        self.key = key
        self.label = label
        self.percentage = percentage
        self.resetTime = resetTime
        self.colorName = colorName
    }
}

public struct QuotaSnapshot: Codable, Equatable {
    public let available: Bool
    public let level: String?
    public let items: [QuotaLimitItem]

    public init(available: Bool, level: String? = nil, items: [QuotaLimitItem] = []) {
        self.available = available
        self.level = level
        self.items = items
    }
}

struct AccountState: Codable, Equatable {
    let authenticated: Bool
    let activeProvider: String
    let profile: UserProfile?
    let displayName: String
    let stableId: String
    var quota: QuotaSnapshot? = nil
}

struct CapturedTarget: Codable, Equatable {
    let id: String
    let type: String
    let captured: Bool
    let required: Bool?
    let error: String?
}

struct ProfileManifest: Codable, Identifiable, Equatable {
    var id: String
    let version: Int
    var name: String
    let createdAt: String
    var updatedAt: String
    let account: AccountState
    var quota: QuotaSnapshot? = nil
    let captured: [CapturedTarget]
    let snapshotReady: Bool
    let pendingSnapshot: Bool
}
