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

struct AccountState: Codable, Equatable {
    let authenticated: Bool
    let activeProvider: String
    let profile: UserProfile?
    let displayName: String
    let stableId: String
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
    let captured: [CapturedTarget]
    let snapshotReady: Bool
    let pendingSnapshot: Bool
}
