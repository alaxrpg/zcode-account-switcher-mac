import SwiftUI
import AppKit

struct ContentView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        NavigationSplitView {
            SidebarView(appState: appState)
                .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 260)
        } detail: {
            DetailContentView(appState: appState)
        }
        .frame(minWidth: 640, idealWidth: 940, maxWidth: .infinity, minHeight: 480, idealHeight: 640, maxHeight: .infinity)
        .alert(appState.alertTitle, isPresented: $appState.showAlert) {
            Button("确定", role: .cancel) { }
        } message: {
            Text(appState.alertMessage)
        }
        .confirmationDialog(
            "确定删除账号快照“\(appState.profileToDelete?.name ?? "")”？",
            isPresented: $appState.showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("确定删除", role: .destructive) {
                appState.confirmDelete()
            }
            Button("取消", role: .cancel) {
                appState.profileToDelete = nil
            }
        } message: {
            Text("删除后该快照凭据文件将从本地被永久移除，无法恢复。")
        }
        .sheet(isPresented: $appState.showingSaveModal) {
            SaveProfileModalView(appState: appState)
        }
    }
}

// MARK: - Apple Maps Standard Crystal Liquid Glass Lens Button
struct LiquidGlassMacOS27ButtonStyle: ButtonStyle {
    var isProminent: Bool = true
    var isDestructive: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 6) {
            configuration.label
        }
        .font(.system(size: 13, weight: .bold, design: .rounded))
        .foregroundColor(isDestructive ? .red : (isProminent ? .blue : .primary))
        .padding(.horizontal, 15)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .background(
            LinearGradient(
                colors: [
                    Color.white.opacity(configuration.isPressed ? 0.55 : 0.40),
                    Color.white.opacity(configuration.isPressed ? 0.20 : 0.12)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .clipShape(Capsule())
        .overlay(
            // 3. Pure White Liquid Glass 3D Specular Ring (Zero Artificial Red/Blue Glow)
            Capsule()
                .stroke(
                    LinearGradient(
                        colors: configuration.isPressed
                            ? [Color.white.opacity(0.95), Color.white.opacity(0.4)]
                            : [Color.white.opacity(0.9), Color.white.opacity(0.25)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: configuration.isPressed ? 1.5 : 1.2
                )
        )
        // 4. Floating Ambient Soft Shadow
        .shadow(
            color: Color.black.opacity(configuration.isPressed ? 0.14 : 0.08),
            radius: configuration.isPressed ? 8 : 5,
            x: 0,
            y: configuration.isPressed ? 2 : 3
        )
        // 5. Tactile Fluid Press Compression Physics
        .scaleEffect(
            configuration.isPressed
                ? CGSize(width: 0.95, height: 0.95)
                : CGSize(width: 1.0, height: 1.0)
        )
        .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Apple Maps Standard Floating Circular Liquid Glass Disk Button
struct LiquidGlassMacOS27IconButtonStyle: ButtonStyle {
    var isDestructive: Bool = false
    var diameter: CGFloat = 34

    func makeBody(configuration: Configuration) -> some View {
        ZStack {
            // 1. Crystal Specular Top-Down Reflective Lens Sheen
            LinearGradient(
                colors: [
                    Color.white.opacity(configuration.isPressed ? 0.55 : 0.40),
                    Color.white.opacity(configuration.isPressed ? 0.20 : 0.12)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            
            configuration.label
                .font(.system(size: diameter * 0.42, weight: .bold))
                .foregroundColor(isDestructive ? .red : .primary)
        }
        .frame(width: diameter, height: diameter)
        .background(.ultraThinMaterial)
        .clipShape(Circle())
        .overlay(
            // 3. Pure White Liquid Glass Circle Specular Ring (Zero Artificial Red/Blue Glow)
            Circle()
                .stroke(
                    LinearGradient(
                        colors: configuration.isPressed
                            ? [Color.white.opacity(0.95), Color.white.opacity(0.4)]
                            : [Color.white.opacity(0.9), Color.white.opacity(0.25)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: configuration.isPressed ? 1.5 : 1.2
                )
        )
        // 4. Floating Ambient Soft Shadow
        .shadow(
            color: Color.black.opacity(configuration.isPressed ? 0.14 : 0.08),
            radius: configuration.isPressed ? 7 : 5,
            x: 0,
            y: configuration.isPressed ? 2 : 3
        )
        // 5. Tactile Fluid Press Scale
        .scaleEffect(
            configuration.isPressed
                ? CGSize(width: 0.92, height: 0.92)
                : CGSize(width: 1.0, height: 1.0)
        )
        .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Apple Maps Style Dual-Layer Outer Liquid Glass Container
struct DualLayerGlassContainer<Content: View>: View {
    let content: Content
    var cornerRadius: CGFloat = 20

    init(cornerRadius: CGFloat = 20, @ViewBuilder content: () -> Content) {
        self.cornerRadius = cornerRadius
        self.content = content()
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.white.opacity(0.42),
                    Color.white.opacity(0.15)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            content
                .padding(22)
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(
            // Pure White Pure Crystal Dual-Layer Edge Specular Ring (Zero Blue Glow)
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.9),
                            Color.white.opacity(0.3)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.2
                )
        )
        .shadow(color: Color.black.opacity(0.12), radius: 16, x: 0, y: 6)
    }
}

// MARK: - Inner Sub-Glass Floating Component
struct InnerGlassPill<Content: View>: View {
    let content: Content
    var cornerRadius: CGFloat = 12

    init(cornerRadius: CGFloat = 12, @ViewBuilder content: () -> Content) {
        self.cornerRadius = cornerRadius
        self.content = content()
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.white.opacity(0.4),
                    Color.white.opacity(0.12)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            content
        }
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.85),
                            Color.white.opacity(0.2)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: Color.black.opacity(0.06), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Native macOS Sidebar View (Apple Maps Weather Card Style Bottom Status)
struct SidebarView: View {
    @ObservedObject var appState: AppState

    var zcodeLogo: NSImage? {
        if let path = Bundle.main.path(forResource: "zcode-logo", ofType: "png"),
           let img = NSImage(contentsOfFile: path) {
            return img
        }
        if let img = NSImage(contentsOfFile: "/Applications/ZCode.app/Contents/Resources/icon.png") {
            return img
        }
        return nil
    }

    var body: some View {
        ZStack {
            VisualEffectBlur(material: .sidebar, blendingMode: .behindWindow)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                List(selection: Binding(
                    get: { appState.selectedTab },
                    set: { if let newTab = $0 { appState.selectedTab = newTab } }
                )) {
                    Section("账号与凭据") {
                        ForEach(SidebarTab.allCases) { tab in
                            NavigationLink(value: tab) {
                                Label(tab.rawValue, systemImage: tab.iconName)
                            }
                        }
                    }
                }
                .listStyle(.sidebar)
                .frame(maxHeight: .infinity)

                // Apple Maps Weather Card Style Status Card
                InnerGlassPill(cornerRadius: 14) {
                    VStack(alignment: .leading, spacing: 8) {
                        // Top Row: Main Official ZCode Logo + Bold Temperature/Status
                        HStack(alignment: .center, spacing: 8) {
                            if let logo = zcodeLogo {
                                Image(nsImage: logo)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 22, height: 22)
                                    .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                                    .shadow(color: Color.black.opacity(0.1), radius: 2)
                            } else {
                                Image(systemName: "terminal.fill")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(appState.isZCodeRunning ? .green : .secondary)
                            }
                            
                            Text("ZCode")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Text(appState.isZCodeRunning ? "运行中" : "未启动")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundColor(appState.isZCodeRunning ? .primary : .secondary)
                        }
                        
                        // Bottom Row: AQI Style Subtitle + Right Green Indicator Dot
                        HStack(alignment: .center) {
                            Text(appState.currentState.displayName)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.primary)
                                .lineLimit(1)
                            
                            Spacer()
                            
                            HStack(spacing: 6) {
                                if appState.isZCodeRunning {
                                    Button(action: { appState.stopZCode() }) {
                                        Image(systemName: "stop.circle.fill")
                                    }
                                    .buttonStyle(LiquidGlassMacOS27IconButtonStyle(isDestructive: false, diameter: 22))
                                    .help("关闭 ZCode App")
                                } else {
                                    Button(action: { appState.launchZCode() }) {
                                        Image(systemName: "play.circle.fill")
                                    }
                                    .buttonStyle(LiquidGlassMacOS27IconButtonStyle(isDestructive: false, diameter: 22))
                                    .help("启动 ZCode App")
                                }
                                
                                Circle()
                                    .fill(appState.currentState.authenticated ? Color.green : Color.orange)
                                    .frame(width: 7, height: 7)
                                    .shadow(color: appState.currentState.authenticated ? Color.green.opacity(0.8) : Color.orange.opacity(0.8), radius: 3)
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                }
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 10)
                .padding(.bottom, 10)
            }
        }
    }
}

// MARK: - Main Detail Content View (With Apple Maps Style Top Header Banner)
struct DetailContentView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        ZStack {
            VisualEffectBlur(material: .fullScreenUI, blendingMode: .behindWindow)
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Apple Maps Style Prominent Large Title Header
                    AppleMapsHeaderView(appState: appState)

                    switch appState.selectedTab {
                    case .overview:
                        OverviewDetailView(appState: appState)
                    case .profiles:
                        ProfilesDetailView(appState: appState)
                    }
                }
                .padding(28)
            }
        }
    }
}

// MARK: - Apple Maps Style Large Title Header Component
struct AppleMapsHeaderView: View {
    @ObservedObject var appState: AppState

    var titleText: String {
        switch appState.selectedTab {
        case .overview:
            return "概览与凭据"
        case .profiles:
            return "账号快照"
        }
    }

    var body: some View {
        HStack(alignment: .center) {
            // Prominent Apple Maps Rounded Title
            Text(titleText)
                .font(.system(size: 28, weight: .heavy, design: .rounded))
                .foregroundColor(.primary)
                .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
            
            Spacer()
            
            // Apple Maps Style Floating Liquid Glass Action Icon Disk Group
            HStack(spacing: 10) {
                if appState.selectedTab == .overview {
                    Button(action: {
                        appState.promptSaveModal()
                    }) {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(LiquidGlassMacOS27IconButtonStyle(diameter: 34))
                    .disabled(!appState.currentState.authenticated || appState.isOperating)
                    .help("保存当前账号为新快照")
                }
                
                // Apple Maps Circular Glass Refresh Disk
                Button(action: {
                    appState.refreshAll()
                }) {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(LiquidGlassMacOS27IconButtonStyle(diameter: 34))
                .help("刷新状态与数据")
            }
        }
        .padding(.bottom, 4)
    }
}

// MARK: - Overview Detail View
struct OverviewDetailView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Hero Active Account Card
            HeroAccountCard(appState: appState)

            // Saved Profiles Section
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("最近账号快照")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    Spacer()
                    Button("查看全部 (\(appState.profiles.count))") {
                        appState.selectedTab = .profiles
                    }
                    .buttonStyle(.link)
                    .font(.system(size: 13, weight: .semibold))
                }
                
                if appState.profiles.isEmpty {
                    EmptyProfilesView(appState: appState)
                } else {
                    VStack(spacing: 14) {
                        ForEach(appState.profiles.prefix(3)) { profile in
                            ProfileRowView(
                                profile: profile,
                                isCurrent: profile.account.stableId == appState.currentState.stableId,
                                onSwitch: { appState.switchProfile(id: profile.id) },
                                onDelete: { appState.promptDeleteConfirmation(profile: profile) }
                            )
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Profiles Detail View
struct ProfilesDetailView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("切换账号时，系统会自动将当前工作凭据无损备份至 switch-backups 目录")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Toggle("切换后自动重启 ZCode App", isOn: $appState.restartZCodeOnSwitch)
                    .toggleStyle(.checkbox)
                    .font(.system(size: 12, weight: .medium))
            }
            
            if appState.profiles.isEmpty {
                EmptyProfilesView(appState: appState)
            } else {
                VStack(spacing: 14) {
                    ForEach(appState.profiles) { profile in
                        ProfileRowView(
                            profile: profile,
                            isCurrent: profile.account.stableId == appState.currentState.stableId,
                            onSwitch: { appState.switchProfile(id: profile.id) },
                            onDelete: { appState.promptDeleteConfirmation(profile: profile) }
                        )
                    }
                }
            }
        }
    }
}

// MARK: - Quota Cards SwiftUI View (Single-Pass Fast Layout & Redacted Skeleton)
struct QuotaCardsSwiftUIView: View {
    let quota: QuotaSnapshot?
    var isLoading: Bool = false

    var items: [QuotaLimitItem] {
        quota?.items ?? []
    }

    var body: some View {
        Group {
            if isLoading || quota == nil {
                // Apple Official .redacted(reason: .placeholder) Loading Skeleton State
                HStack(spacing: 8) {
                    QuotaItemSkeletonView()
                    QuotaItemSkeletonView()
                    QuotaItemSkeletonView()
                }
                .redacted(reason: .placeholder)
            } else if let q = quota, q.available, !items.isEmpty {
                // Single-Pass High-Performance Adaptive Row
                HStack(spacing: 8) {
                    ForEach(items) { item in
                        QuotaItemColumnView(item: item)
                    }
                }
            }
        }
    }
}

struct QuotaItemSkeletonView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 3) {
                Text("5小时")
                    .font(.system(size: 11, weight: .regular))
                Text("88%")
                    .font(.system(size: 12, weight: .bold))
                Text("· 20:00")
                    .font(.system(size: 10, weight: .regular))
            }
            Capsule()
                .fill(Color.primary.opacity(0.12))
                .frame(height: 4)
        }
        .frame(minWidth: 64, idealWidth: 88, maxWidth: 100)
    }
}

struct QuotaItemColumnView: View {
    let item: QuotaLimitItem

    var fillColor: Color {
        switch item.colorName {
        case "green":
            return Color(red: 0.06, green: 0.72, blue: 0.45)
        case "purple":
            return Color(red: 0.54, green: 0.36, blue: 0.96)
        default:
            return Color(red: 0.0, green: 0.48, blue: 1.0)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 3) {
                Text(item.label)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Text("\(item.percentage)%")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                if let reset = item.resetTime, !reset.isEmpty {
                    Text("· \(reset)")
                        .font(.system(size: 10, weight: .regular))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }

            // Pure Specular Capsule Fill Bar (Focus Independent - Never turns gray on window defocus)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.primary.opacity(0.12))

                    Capsule()
                        .fill(fillColor)
                        .frame(width: max(0, min(geo.size.width, geo.size.width * CGFloat(item.percentage) / 100.0)))
                }
            }
            .frame(height: 4)
        }
        .frame(minWidth: 64, idealWidth: 88, maxWidth: 110)
    }
}

// MARK: - Hero Active Account Card (Apple Maps Weather Card Style Status)
struct HeroAccountCard: View {
    @ObservedObject var appState: AppState

    var body: some View {
        DualLayerGlassContainer(cornerRadius: 20) {
            HStack(alignment: .center, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        AppleMapsWeatherStatusBadge(isAuthenticated: appState.currentState.authenticated)
                        ProviderBadge(provider: appState.currentState.activeProvider)
                    }

                    Text(appState.currentState.displayName)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }

                Spacer(minLength: 8)

                QuotaCardsSwiftUIView(quota: appState.currentState.quota, isLoading: appState.isQuotaLoading)

                Spacer(minLength: 8)

                Button(action: {
                    appState.promptSaveModal()
                }) {
                    Image(systemName: "plus")
                }
                .buttonStyle(LiquidGlassMacOS27IconButtonStyle(diameter: 36))
                .disabled(!appState.currentState.authenticated || appState.isOperating)
                .help("保存当前账号为新快照")
            }
        }
    }
}

// MARK: - Apple Maps Weather Style Status Badge for Hero View
struct AppleMapsWeatherStatusBadge: View {
    let isAuthenticated: Bool

    var body: some View {
        InnerGlassPill(cornerRadius: 12) {
            HStack(spacing: 8) {
                Image(systemName: isAuthenticated ? "shield.checkmark.fill" : "exclamationmark.triangle.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(isAuthenticated ? .green : .orange)
                
                VStack(alignment: .leading, spacing: 1) {
                    Text(isAuthenticated ? "工作中" : "未登录")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    Text("工作凭据就绪")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                
                Circle()
                    .fill(isAuthenticated ? Color.green : Color.orange)
                    .frame(width: 6, height: 6)
                    .shadow(color: isAuthenticated ? Color.green.opacity(0.8) : Color.orange.opacity(0.8), radius: 3)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
        }
        .fixedSize()
    }
}

// MARK: - Profile Row View
struct ProfileRowView: View {
    let profile: ProfileManifest
    let isCurrent: Bool
    let onSwitch: () -> Void
    let onDelete: () -> Void

    var body: some View {
        DualLayerGlassContainer(cornerRadius: 14) {
            HStack(alignment: .center, spacing: 10) {
                // Name & Status Badges (包含 "使用中")
                HStack(spacing: 8) {
                    Text(profile.name)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)

                    if isCurrent {
                        RowActiveBadge()
                    }

                    ProviderBadge(provider: profile.account.activeProvider)
                }

                Spacer(minLength: 6)

                // 额度三栏进度条 (接入 Apple Redacted Placeholder 加载状态)
                QuotaCardsSwiftUIView(quota: profile.quota, isLoading: false)

                Spacer(minLength: 6)

                // 操作按钮
                HStack(spacing: 10) {
                    if !isCurrent {
                        Button(action: onSwitch) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                        }
                        .buttonStyle(LiquidGlassMacOS27IconButtonStyle(diameter: 32))
                        .help("一键切换至此账号")
                    }

                    Button(action: onDelete) {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(LiquidGlassMacOS27IconButtonStyle(isDestructive: true, diameter: 32))
                    .help("删除此快照（包含二次确认）")
                }
            }
        }
    }
}

// MARK: - Apple Maps Weather Style Row Active Badge (使用中)
struct RowActiveBadge: View {
    var body: some View {
        InnerGlassPill(cornerRadius: 10) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.green)
                    
                    Text("使用中")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                }
                
                HStack(spacing: 5) {
                    Text("当前环境")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundColor(.secondary)
                    
                    Circle()
                        .fill(Color.green)
                        .frame(width: 4, height: 4)
                        .shadow(color: Color.green.opacity(0.8), radius: 2)
                }
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
        }
        .fixedSize()
    }
}

// MARK: - Liquid Glass Provider Badge (No Blue Dot, Single Line)
struct ProviderBadge: View {
    let provider: String
    
    var isZAI: Bool {
        provider.lowercased().contains("zai")
    }

    var body: some View {
        InnerGlassPill(cornerRadius: 10) {
            HStack(spacing: 6) {
                Image(systemName: isZAI ? "globe.asia.pacific.fill" : "cpu.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(isZAI ? .purple : .blue)
                
                Text(isZAI ? "Z.ai 国际" : "BigModel 国内")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
        }
        .fixedSize()
    }
}

// MARK: - Empty Profiles View
struct EmptyProfilesView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        DualLayerGlassContainer(cornerRadius: 14) {
            VStack(spacing: 14) {
                Image(systemName: "square.stack.3d.up.slash")
                    .font(.system(size: 38))
                
                Text("暂未保存任何 ZCode 账号快照")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
                
                Button(action: {
                    appState.promptSaveModal()
                }) {
                    Image(systemName: "plus")
                }
                .buttonStyle(LiquidGlassMacOS27IconButtonStyle(diameter: 38))
                .help("保存当前账号为第一个快照")
            }
            .frame(maxWidth: .infinity)
            .padding(28)
        }
    }
}

// MARK: - Save Modal
struct SaveProfileModalView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("保存账号凭据快照")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.primary)
            
            Text("为您当前的 ZCode 凭据配置一个便于分辨的别名：")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            
            TextField("例如: 工作号 / 个人号", text: $appState.customProfileName)
                .textFieldStyle(.roundedBorder)
            
            HStack {
                Spacer()
                Button("取消") {
                    appState.showingSaveModal = false
                }
                .buttonStyle(.bordered)
                .keyboardShortcut(.escape, modifiers: [])
                
                Button(action: {
                    appState.saveCurrentSnapshot(customName: appState.customProfileName)
                }) {
                    Text("确认保存")
                }
                .buttonStyle(LiquidGlassMacOS27ButtonStyle(isProminent: true))
                .keyboardShortcut(.return, modifiers: [])
                .disabled(appState.customProfileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 360)
    }
}

// MARK: - Visual Effect Blur Helper
struct VisualEffectBlur: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
