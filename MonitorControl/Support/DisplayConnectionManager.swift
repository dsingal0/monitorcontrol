//  Copyright © MonitorControl. @JoniVR, @theOneyouseek, @waydabber and others

import Cocoa
import CoreGraphics
import os.log

@_silgen_name("CGSConfigureDisplayEnabled")
func CGSConfigureDisplayEnabled(_ cid: CGDisplayConfigRef, _ display: UInt32, _ enabled: Bool) -> Int

enum DisplayConnectionError: Error, LocalizedError {
    case beginConfigurationFailed
    case configureFailed(displayID: CGDirectDisplayID)
    case completeConfigurationFailed
    case noDisplaysAvailable
    case cannotDisconnectLastDisplay
    
    var errorDescription: String? {
        switch self {
        case .beginConfigurationFailed:
            return NSLocalizedString("Failed to begin display configuration", comment: "Error message")
        case .configureFailed(let displayID):
            return String(format: NSLocalizedString("Failed to configure display %u", comment: "Error message"), displayID)
        case .completeConfigurationFailed:
            return NSLocalizedString("Failed to complete display configuration", comment: "Error message")
        case .noDisplaysAvailable:
            return NSLocalizedString("No displays available", comment: "Error message")
        case .cannotDisconnectLastDisplay:
            return NSLocalizedString("Cannot disconnect the last active display", comment: "Error message")
        }
    }
}

class DisplayConnectionManager {
    static let shared = DisplayConnectionManager()
    
    private var disconnectedDisplays: Set<CGDirectDisplayID> = []
    
    private init() {}
    
    func getActiveDisplayCount() -> Int {
        var displayCount: UInt32 = 0
        var activeDisplays = [CGDirectDisplayID](repeating: 0, count: 16)
        CGGetActiveDisplayList(16, &activeDisplays, &displayCount)
        return Int(displayCount)
    }
    
    func getActiveDisplayIDs() -> [CGDirectDisplayID] {
        var displayCount: UInt32 = 0
        var activeDisplays = [CGDirectDisplayID](repeating: 0, count: 16)
        let result = CGGetActiveDisplayList(16, &activeDisplays, &displayCount)
        guard result == .success else { return [] }
        return Array(activeDisplays.prefix(Int(displayCount)))
    }
    
    func getOnlineDisplayIDs() -> [CGDirectDisplayID] {
        var displayCount: UInt32 = 0
        var onlineDisplays = [CGDirectDisplayID](repeating: 0, count: 16)
        let result = CGGetOnlineDisplayList(16, &onlineDisplays, &displayCount)
        guard result == .success else { return [] }
        return Array(onlineDisplays.prefix(Int(displayCount)))
    }
    
    func isDisplayActive(_ displayID: CGDirectDisplayID) -> Bool {
        return getActiveDisplayIDs().contains(displayID)
    }
    
    func isDisplayOnline(_ displayID: CGDirectDisplayID) -> Bool {
        return getOnlineDisplayIDs().contains(displayID)
    }
    
    func disconnectDisplay(_ displayID: CGDirectDisplayID) throws {
        let activeCount = getActiveDisplayCount()
        guard activeCount > 1 else {
            os_log("Cannot disconnect display %u - it's the only active display", type: .error, displayID)
            throw DisplayConnectionError.cannotDisconnectLastDisplay
        }
        
        guard isDisplayActive(displayID) else {
            os_log("Display %u is not active, cannot disconnect", type: .info, displayID)
            return
        }
        
        var configRef: CGDisplayConfigRef?
        let beginStatus = CGBeginDisplayConfiguration(&configRef)
        
        guard beginStatus == .success, let config = configRef else {
            os_log("Failed to begin display configuration for disconnect", type: .error)
            throw DisplayConnectionError.beginConfigurationFailed
        }
        
        let status = CGSConfigureDisplayEnabled(config, displayID, false)
        guard status == 0 else {
            CGCancelDisplayConfiguration(config)
            os_log("Failed to disconnect display %u, status: %d", type: .error, displayID, status)
            throw DisplayConnectionError.configureFailed(displayID: displayID)
        }
        
        let completeStatus = CGCompleteDisplayConfiguration(config, .permanently)
        guard completeStatus == .success else {
            os_log("Failed to complete display configuration for disconnect", type: .error)
            throw DisplayConnectionError.completeConfigurationFailed
        }

        disconnectedDisplays.insert(displayID)
        os_log("Successfully disconnected display %u", type: .info, displayID)
    }
    
    func reconnectDisplay(_ displayID: CGDirectDisplayID) throws {
        guard !isDisplayActive(displayID) else {
            os_log("Display %u is already active", type: .info, displayID)
            disconnectedDisplays.remove(displayID)
            return
        }

        var configRef: CGDisplayConfigRef?
        let beginStatus = CGBeginDisplayConfiguration(&configRef)

        guard beginStatus == .success, let config = configRef else {
            os_log("Failed to begin display configuration for reconnect", type: .error)
            throw DisplayConnectionError.beginConfigurationFailed
        }

        let status = CGSConfigureDisplayEnabled(config, displayID, true)
        guard status == 0 else {
            CGCancelDisplayConfiguration(config)
            os_log("Failed to reconnect display %u, status: %d", type: .error, displayID, status)
            throw DisplayConnectionError.configureFailed(displayID: displayID)
        }

        let completeStatus = CGCompleteDisplayConfiguration(config, .permanently)
        guard completeStatus == .success else {
            os_log("Failed to complete display configuration for reconnect", type: .error)
            throw DisplayConnectionError.completeConfigurationFailed
        }

        disconnectedDisplays.remove(displayID)
        os_log("Successfully reconnected display %u", type: .info, displayID)
    }
    
    func setDisplayEnabled(_ displayID: CGDirectDisplayID, enabled: Bool) throws {
        if enabled {
            try reconnectDisplay(displayID)
        } else {
            try disconnectDisplay(displayID)
        }
    }
    
    func resetAllDisplays() {
        os_log("Resetting all displays to active state", type: .info)
        let toReconnect = Array(disconnectedDisplays)
        disconnectedDisplays.removeAll()

        guard !toReconnect.isEmpty else { return }

        var configRef: CGDisplayConfigRef?
        guard CGBeginDisplayConfiguration(&configRef) == .success, let config = configRef else {
            os_log("Failed to begin display configuration for reset", type: .error)
            return
        }

        for displayID in toReconnect {
            let status = CGSConfigureDisplayEnabled(config, displayID, true)
            os_log("Re-enabling display %u, status: %d", type: .info, displayID, status)
        }

        let result = CGCompleteDisplayConfiguration(config, .permanently)
        os_log("Reset all displays result: %d", type: .info, result.rawValue)
        CGDisplayRestoreColorSyncSettings()
    }
    
    func getDisconnectedDisplayIDs() -> Set<CGDirectDisplayID> {
        return disconnectedDisplays
    }

    func getBuiltInDisplayID() -> CGDirectDisplayID? {
        for displayID in getOnlineDisplayIDs() {
            if CGDisplayIsBuiltin(displayID) != 0 {
                return displayID
            }
        }
        return nil
    }
    
    func getExternalDisplayIDs() -> [CGDirectDisplayID] {
        return getOnlineDisplayIDs().filter { CGDisplayIsBuiltin($0) == 0 }
    }
    
    func hasExternalDisplay() -> Bool {
        return !getExternalDisplayIDs().isEmpty
    }
}
