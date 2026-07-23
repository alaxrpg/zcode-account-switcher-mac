import Foundation
import AppKit

struct ZCodeProcessManager {
    static let possibleAppPaths = [
        "/Applications/ZCode.app",
        (NSHomeDirectory() as NSString).appendingPathComponent("Applications/ZCode.app")
    ]

    /// Electron stores its single-instance lock here (symlink: hostname-PID).
    static var singletonLockPath: String {
        (NSHomeDirectory() as NSString).appendingPathComponent("Library/Application Support/ZCode/SingletonLock")
    }

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

    // MARK: - Stale Lock Cleanup

    /// Remove a stale Electron single-instance lock symlink if the owning PID is dead.
    /// This prevents the next launch from suiciding due to a leftover lock.
    static func cleanStaleSingletonLock() {
        let lockPath = singletonLockPath
        guard FileManager.default.fileExists(atPath: lockPath) else { return }

        // SingletonLock is a symlink: "hostname-PID"
        if let target = try? FileManager.default.destinationOfSymbolicLink(atPath: lockPath) {
            // Extract PID from the rightmost dash (hostname may contain dashes)
            if let lastDash = target.lastIndex(of: "-") {
                let pidStr = String(target[target.index(after: lastDash)...])
                if let pid = pid_t(pidStr), pid > 0 {
                    // kill(pid, 0) returns 0 if process is alive, -1 (errno ESRCH) if dead
                    let alive = kill(pid, 0) == 0
                    if !alive {
                        try? FileManager.default.removeItem(atPath: lockPath)
                    }
                    return
                }
            }
            // Can't parse PID — only remove if no ZCode is running
            if getZCodeApplications().isEmpty {
                try? FileManager.default.removeItem(atPath: lockPath)
            }
        } else {
            // Broken symlink or regular file — remove if no ZCode running
            if getZCodeApplications().isEmpty {
                try? FileManager.default.removeItem(atPath: lockPath)
            }
        }
    }

    // MARK: - Stop (async, waits for full exit)

    /// Gracefully stop ZCode and wait until the process has fully exited.
    /// Escalates from `terminate()` → `forceTerminate()` → `kill -9` as needed,
    /// then cleans up the stale single-instance lock.
    /// Returns true if ZCode is no longer running.
    static func stopZCode() async -> Bool {
        let apps = getZCodeApplications()
        if apps.isEmpty {
            cleanStaleSingletonLock()
            return true
        }

        // 1. Request graceful termination (SIGTERM via NSRunningApplication)
        for app in apps {
            _ = app.terminate()
        }

        // 2. Poll for graceful exit (up to 4s, checking every 0.2s)
        let gracefulDeadline = Date().addingTimeInterval(4.0)
        while Date() < gracefulDeadline {
            if getZCodeApplications().isEmpty { break }
            try? await Task.sleep(nanoseconds: 200_000_000)
        }

        // 3. Force-kill if still alive
        let stillRunning = getZCodeApplications()
        if !stillRunning.isEmpty {
            for app in stillRunning {
                _ = app.forceTerminate()
            }
            // Also SIGKILL the main process by exact name to catch stray helpers
            let killTask = Process()
            killTask.executableURL = URL(fileURLWithPath: "/usr/bin/pkill")
            killTask.arguments = ["-9", "-x", "ZCode"]
            try? killTask.run()
            killTask.waitUntilExit()

            // Wait for force-kill to complete (up to 3s)
            let forceDeadline = Date().addingTimeInterval(3.0)
            while Date() < forceDeadline {
                if getZCodeApplications().isEmpty { break }
                try? await Task.sleep(nanoseconds: 200_000_000)
            }
        }

        // 4. Clean stale singleton lock so the next launch won't conflict
        cleanStaleSingletonLock()

        return getZCodeApplications().isEmpty
    }

    // MARK: - Launch (async, with retry for single-instance lock race)

    /// Launch ZCode, retrying up to `maxAttempts` times to survive the
    /// single-instance-lock suicide race. Verifies the process is actually
    /// running after each attempt.
    static func launchZCode(maxAttempts: Int = 3) async throws {
        guard let appPath = findZCodeInstall() else {
            throw NSError(domain: "ZCodeProcessManager", code: 404, userInfo: [NSLocalizedDescriptionKey: "未在系统的 Applications 目录找到 ZCode.app"])
        }
        let url = URL(fileURLWithPath: appPath)

        for attempt in 1...maxAttempts {
            // Ensure no stale lock before launching
            cleanStaleSingletonLock()

            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = true

            do {
                _ = try await NSWorkspace.shared.openApplication(at: url, configuration: configuration)
            } catch {
                // If this is the last attempt, surface the error
                if attempt == maxAttempts {
                    throw NSError(domain: "ZCodeProcessManager", code: 503, userInfo: [NSLocalizedDescriptionKey: "ZCode 启动失败：\(error.localizedDescription)"])
                }
            }

            // Wait for the app to initialize (Electron startup is slow).
            // This also catches the single-instance suicide: the new process
            // launches, sees the lock, and exits within ~2s.
            try? await Task.sleep(nanoseconds: 2_500_000_000)

            if isZCodeRunning() {
                return // Successfully launched and survived
            }

            // App didn't survive — likely lost the single-instance race.
            // Clean up and wait before retrying.
            if attempt < maxAttempts {
                cleanStaleSingletonLock()
                try? await Task.sleep(nanoseconds: 1_500_000_000)
            }
        }

        // All attempts exhausted
        throw NSError(domain: "ZCodeProcessManager", code: 503, userInfo: [NSLocalizedDescriptionKey: "ZCode 启动失败（多次重试后仍无法启动，可能存在单实例锁冲突），请稍后手动启动"])
    }

    // MARK: - Relaunch (stop → wait → launch)

    /// Stop ZCode, wait for full exit + lock release, then relaunch with retry.
    static func relaunchZCode() async throws {
        _ = await stopZCode()
        try await launchZCode()
    }
}
