import Foundation
import AppKit

struct ZCodeProcessManager {
    static let possibleAppPaths = [
        "/Applications/ZCode.app",
        (NSHomeDirectory() as NSString).appendingPathComponent("Applications/ZCode.app")
    ]
    
    static func findZCodeInstall() -> String? {
        for path in possibleAppPaths {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }
        return nil
    }
    
    static func getZCodeApplications() -> [NSRunningApplication] {
        let ownPid = ProcessInfo.processInfo.processIdentifier
        let running = NSWorkspace.shared.runningApplications
        return running.filter { app in
            // Exclude our own account switcher app process
            if app.processIdentifier == ownPid {
                return false
            }
            if let bundleId = app.bundleIdentifier?.lowercased(),
               bundleId.contains("switcher") || bundleId.contains("accountswitcher") {
                return false
            }
            if let name = app.localizedName?.lowercased(),
               name.contains("switcher") {
                return false
            }
            
            // Match strictly the main ZCode.app target
            if let path = app.bundleURL?.path, path.hasSuffix("ZCode.app") || path.hasSuffix("ZCode.app/") {
                return true
            }
            if let name = app.localizedName, name == "ZCode" {
                return true
            }
            return false
        }
    }
    
    static func isZCodeRunning() -> Bool {
        return !getZCodeApplications().isEmpty
    }
    
    static func stopZCode() -> Bool {
        let apps = getZCodeApplications()
        if apps.isEmpty {
            return true
        }
        
        let stoppedAll = true
        for app in apps {
            let success = app.terminate()
            if !success {
                _ = app.forceTerminate()
            }
        }
        
        // Exact process kill for ZCode without affecting ZCode Account Switcher
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/pkill")
        task.arguments = ["-x", "ZCode"]
        try? task.run()
        task.waitUntilExit()
        
        return stoppedAll
    }
    
    static func launchZCode() throws {
        guard let appPath = findZCodeInstall() else {
            throw NSError(domain: "ZCodeProcessManager", code: 404, userInfo: [NSLocalizedDescriptionKey: "未在系统的 Applications 目录找到 ZCode.app"])
        }
        let url = URL(fileURLWithPath: appPath)
        let configuration = NSWorkspace.OpenConfiguration()
        NSWorkspace.shared.openApplication(at: url, configuration: configuration) { _, error in
            if let error = error {
                print("Failed to launch ZCode: \(error.localizedDescription)")
            }
        }
    }
}
