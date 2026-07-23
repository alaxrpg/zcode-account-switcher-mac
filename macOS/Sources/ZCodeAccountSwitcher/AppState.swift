import Foundation
import Combine
import AppKit

@MainActor
class AppState: ObservableObject {
    @Published var currentState: AccountState
    @Published var profiles: [ProfileManifest] = []
    @Published var isZCodeRunning: Bool = false
    @Published var isOperating: Bool = false
    @Published var alertTitle: String = ""
    @Published var alertMessage: String = ""
    @Published var showAlert: Bool = false
    @Published var restartZCodeOnSwitch: Bool = true
    @Published var showingSaveModal: Bool = false
    @Published var customProfileName: String = ""
    @Published var selectedTab: SidebarTab = .overview
    
    // Delete Confirmation Dialog State
    @Published var profileToDelete: ProfileManifest? = nil
    @Published var showDeleteConfirmation: Bool = false
    
    private var statusTimer: Timer?
    
    init() {
        self.currentState = ProfileManager.readCurrentAccountState()
        refreshAll()
        startStatusPolling()
    }
    
    deinit {
        statusTimer?.invalidate()
    }
    
    /// Poll ZCode process status every 3 seconds for real-time UI updates
    private func startStatusPolling() {
        statusTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                let running = ZCodeProcessManager.isZCodeRunning()
                if self.isZCodeRunning != running {
                    self.isZCodeRunning = running
                }
            }
        }
    }
    
    func refreshAll() {
        self.currentState = ProfileManager.readCurrentAccountState()
        self.profiles = ProfileManager.listProfiles()
        self.isZCodeRunning = ZCodeProcessManager.isZCodeRunning()
    }
    
    func promptSaveModal() {
        self.customProfileName = self.currentState.displayName
        self.showingSaveModal = true
    }
    
    func saveCurrentSnapshot(customName: String? = nil) {
        isOperating = true
        do {
            _ = try ProfileManager.saveCurrentAsProfile(customName: customName)
            self.refreshAll()
            self.isOperating = false
            self.showingSaveModal = false
            self.presentAlert(title: "保存成功", message: "已成功为当前账号创建快照！")
        } catch {
            self.isOperating = false
            self.presentAlert(title: "保存失败", message: error.localizedDescription)
        }
    }
    
    func switchProfile(id: String) {
        isOperating = true
        Task {
            do {
                let targetProfile = profiles.first(where: { $0.id == id })
                let targetName = targetProfile?.name ?? "目标账号"
                
                try ProfileManager.restoreProfile(id: id)
                
                if restartZCodeOnSwitch && ZCodeProcessManager.isZCodeRunning() {
                    _ = ZCodeProcessManager.stopZCode()
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                    try? ZCodeProcessManager.launchZCode()
                }
                
                await MainActor.run {
                    self.refreshAll()
                    self.isOperating = false
                    self.presentAlert(title: "切换成功", message: "已成功切换到账号：\(targetName)")
                }
            } catch {
                await MainActor.run {
                    self.isOperating = false
                    self.presentAlert(title: "切换失败", message: error.localizedDescription)
                }
            }
        }
    }
    
    func promptDeleteConfirmation(profile: ProfileManifest) {
        self.profileToDelete = profile
        self.showDeleteConfirmation = true
    }
    
    func confirmDelete() {
        guard let target = profileToDelete else { return }
        do {
            try ProfileManager.deleteProfile(id: target.id)
            self.profileToDelete = nil
            self.showDeleteConfirmation = false
            refreshAll()
        } catch {
            presentAlert(title: "删除失败", message: error.localizedDescription)
        }
    }
    
    func launchZCode() {
        do {
            try ZCodeProcessManager.launchZCode()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                self.isZCodeRunning = ZCodeProcessManager.isZCodeRunning()
            }
        } catch {
            presentAlert(title: "启动失败", message: error.localizedDescription)
        }
    }
    
    func stopZCode() {
        _ = ZCodeProcessManager.stopZCode()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.isZCodeRunning = ZCodeProcessManager.isZCodeRunning()
        }
    }
    
    private func presentAlert(title: String, message: String) {
        self.alertTitle = title
        self.alertMessage = message
        self.showAlert = true
    }
}
