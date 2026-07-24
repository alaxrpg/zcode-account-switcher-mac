import Foundation
import Combine
import AppKit
import SwiftUI

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
    
    @Published var isQuotaLoading: Bool = true
    
    // Delete Confirmation Dialog State
    @Published var profileToDelete: ProfileManifest? = nil
    @Published var showDeleteConfirmation: Bool = false
    
    private var statusTimer: Timer?
    private var quotaTimer: Timer?
    private var isQuotaRefreshing: Bool = false
    
    init() {
        self.currentState = ProfileManager.readCurrentAccountState()
        refreshAll()
        startStatusPolling()
        startQuotaPolling()
    }
    
    deinit {
        statusTimer?.invalidate()
        quotaTimer?.invalidate()
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
    
    /// Poll quota data every 5 minutes for automatic refresh without skeleton UI
    private func startQuotaPolling() {
        quotaTimer = Timer.scheduledTimer(withTimeInterval: 300.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self, !self.isQuotaRefreshing else { return }
                self.isQuotaRefreshing = true
                defer { self.isQuotaRefreshing = false }
                
                let currentQuota = await ProfileManager.fetchCurrentAccountQuota()
                self.currentState.quota = currentQuota
                
                for index in self.profiles.indices {
                    let p = self.profiles[index]
                    let profileQuota = await ProfileManager.fetchProfileQuota(profileId: p.id)
                    if index < self.profiles.count {
                        self.profiles[index].quota = profileQuota
                    }
                }
            }
        }
    }
    
    func refreshAll() {
        self.currentState = ProfileManager.readCurrentAccountState()
        self.profiles = ProfileManager.listProfiles()
        self.isZCodeRunning = ZCodeProcessManager.isZCodeRunning()
        self.isQuotaLoading = true

        Task {
            let currentQuota = await ProfileManager.fetchCurrentAccountQuota()
            await MainActor.run {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    self.currentState.quota = currentQuota
                }
            }

            for index in self.profiles.indices {
                let p = self.profiles[index]
                let profileQuota = await ProfileManager.fetchProfileQuota(profileId: p.id)
                await MainActor.run {
                    if index < self.profiles.count {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            self.profiles[index].quota = profileQuota
                        }
                    }
                }
            }

            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.35)) {
                    self.isQuotaLoading = false
                }
            }
        }
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
        Task { @MainActor in
            do {
                let targetProfile = profiles.first(where: { $0.id == id })
                let targetName = targetProfile?.name ?? "目标账号"

                try ProfileManager.restoreProfile(id: id)

                if restartZCodeOnSwitch && ZCodeProcessManager.isZCodeRunning() {
                    try await ZCodeProcessManager.relaunchZCode()
                }

                self.refreshAll()
                self.isOperating = false
                self.presentAlert(title: "切换成功", message: "已成功切换到账号：\(targetName)")
            } catch {
                self.isOperating = false
                self.presentAlert(title: "切换失败", message: error.localizedDescription)
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
        Task { @MainActor in
            do {
                try await ZCodeProcessManager.launchZCode()
                self.isZCodeRunning = ZCodeProcessManager.isZCodeRunning()
            } catch {
                self.presentAlert(title: "启动失败", message: error.localizedDescription)
            }
        }
    }

    func stopZCode() {
        Task { @MainActor in
            _ = await ZCodeProcessManager.stopZCode()
            self.isZCodeRunning = ZCodeProcessManager.isZCodeRunning()
        }
    }
    
    private func presentAlert(title: String, message: String) {
        self.alertTitle = title
        self.alertMessage = message
        self.showAlert = true
    }
}
