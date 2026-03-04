//  Copyright © MonitorControl. @JoniVR, @theOneyouseek, @waydabber and others

import Cocoa
import CoreGraphics
import os.log

class LayoutManager {
    static let shared = LayoutManager()
    
    private let layoutsKey = "savedDisplayLayouts"
    private let activeLayoutIdKey = "activeDisplayLayoutId"
    private let autoSwitchKey = "autoSwitchLayouts"
    private let lastExternalStateKey = "lastExternalDisplayState"
    
    private(set) var layouts: [DisplayLayout] = []
    private(set) var activeLayout: DisplayLayout?
    private var lastHadExternal: Bool = false
    
    private init() {
        loadLayouts()
        lastHadExternal = DisplayConnectionManager.shared.hasExternalDisplay()
    }
    
    func loadLayouts() {
        guard let data = prefs.data(forKey: layoutsKey) else {
            layouts = []
            return
        }
        
        do {
            layouts = try JSONDecoder().decode([DisplayLayout].self, from: data)
            os_log("Loaded %d layouts", type: .info, layouts.count)
        } catch {
            os_log("Failed to load layouts: %{public}@", type: .error, error.localizedDescription)
            layouts = []
        }
        
        if let activeIdString = prefs.string(forKey: activeLayoutIdKey),
           let activeId = UUID(uuidString: activeIdString) {
            activeLayout = layouts.first { $0.id == activeId }
        }
    }
    
    func saveLayouts() {
        do {
            let data = try JSONEncoder().encode(layouts)
            prefs.set(data, forKey: layoutsKey)
            os_log("Saved %d layouts", type: .info, layouts.count)
        } catch {
            os_log("Failed to save layouts: %{public}@", type: .error, error.localizedDescription)
        }
    }
    
    func clearActiveLayout() {
        activeLayout = nil
        prefs.removeObject(forKey: activeLayoutIdKey)
    }

    func saveCurrentLayout(name: String) -> DisplayLayout {
        let onlineDisplayIDs = DisplayConnectionManager.shared.getOnlineDisplayIDs()
        let activeDisplayIDs = DisplayConnectionManager.shared.getActiveDisplayIDs()
        let disconnectedDisplayIDs = DisplayConnectionManager.shared.getDisconnectedDisplayIDs()
        let allKnownDisplayIDs = Set(onlineDisplayIDs).union(disconnectedDisplayIDs)

        var displayStates: [DisplayState] = []
        for displayID in allKnownDisplayIDs {
            let isEnabled = activeDisplayIDs.contains(displayID)
            displayStates.append(DisplayState(displayID: displayID, isEnabled: isEnabled))
        }

        let layout = DisplayLayout(name: name, displayStates: displayStates)
        layouts.append(layout)
        activeLayout = layout
        prefs.set(layout.id.uuidString, forKey: activeLayoutIdKey)
        saveLayouts()
        os_log("Saved new layout '%{public}@' with %d displays", type: .info, name, displayStates.count)
        return layout
    }
    
    func updateLayout(_ layout: DisplayLayout, name: String? = nil, displayStates: [DisplayState]? = nil) {
        guard let index = layouts.firstIndex(where: { $0.id == layout.id }) else { return }
        
        if let name = name {
            layouts[index].name = name
        }
        if let displayStates = displayStates {
            layouts[index].displayStates = displayStates
        }
        saveLayouts()
    }
    
    func deleteLayout(_ layout: DisplayLayout) {
        layouts.removeAll { $0.id == layout.id }
        if activeLayout?.id == layout.id {
            activeLayout = nil
            prefs.removeObject(forKey: activeLayoutIdKey)
        }
        saveLayouts()
        os_log("Deleted layout '%{public}@'", type: .info, layout.name)
    }
    
    func applyLayout(_ layout: DisplayLayout) throws {
        os_log("Applying layout '%{public}@'", type: .info, layout.name)

        let onlineDisplayIDs = DisplayConnectionManager.shared.getOnlineDisplayIDs()
        let disconnectedDisplayIDs = DisplayConnectionManager.shared.getDisconnectedDisplayIDs()
        let allKnownDisplayIDs = Set(onlineDisplayIDs).union(disconnectedDisplayIDs)

        var layoutToApply = layout
        layoutToApply.updateLastUsed()
        if let index = layouts.firstIndex(where: { $0.id == layout.id }) {
            layouts[index] = layoutToApply
            saveLayouts()
        }

        for displayID in allKnownDisplayIDs {
            guard let displayState = layout.getDisplayState(for: displayID) else {
                os_log("Display %u not found in layout, enabling by default", type: .info, displayID)
                try DisplayConnectionManager.shared.reconnectDisplay(displayID)
                continue
            }

            try DisplayConnectionManager.shared.setDisplayEnabled(displayID, enabled: displayState.isEnabled)
        }

        activeLayout = layoutToApply
        prefs.set(layout.id.uuidString, forKey: activeLayoutIdKey)

        os_log("Successfully applied layout '%{public}@'", type: .info, layout.name)
    }
    
    func getMatchingLayout(for displayIDs: [CGDirectDisplayID]) -> DisplayLayout? {
        let matchingLayouts = layouts
            .filter { $0.autoSwitch && $0.matches(connectedDisplayIDs: displayIDs) }
            .sorted { ($0.lastUsed ?? Date.distantPast) > ($1.lastUsed ?? Date.distantPast) }
        
        return matchingLayouts.first
    }
    
    func getDefaultLayout() -> DisplayLayout? {
        return layouts.first { $0.isDefault }
    }
    
    func setDefaultLayout(_ layout: DisplayLayout) {
        for i in layouts.indices {
            layouts[i].isDefault = layouts[i].id == layout.id
        }
        saveLayouts()
    }
    
    func checkAndAutoSwitch() -> Bool {
        guard prefs.bool(forKey: autoSwitchKey) else {
            return false
        }
        
        let hasExternal = DisplayConnectionManager.shared.hasExternalDisplay()
        let externalChanged = hasExternal != lastHadExternal
        
        defer {
            lastHadExternal = hasExternal
            prefs.set(hasExternal, forKey: lastExternalStateKey)
        }
        
        guard externalChanged else {
            return false
        }
        
        os_log("External display state changed, checking for auto-switch", type: .info)
        
        let onlineDisplayIDs = DisplayConnectionManager.shared.getOnlineDisplayIDs()
        
        if let matchingLayout = getMatchingLayout(for: onlineDisplayIDs) {
            os_log("Found matching layout '%{public}@', auto-switching", type: .info, matchingLayout.name)
            try? applyLayout(matchingLayout)
            return true
        }
        
        if !hasExternal, let defaultLayout = getDefaultLayout() {
            os_log("No external display, applying default layout '%{public}@'", type: .info, defaultLayout.name)
            try? applyLayout(defaultLayout)
            return true
        }
        
        return false
    }
    
    func setAutoSwitchEnabled(_ enabled: Bool) {
        prefs.set(enabled, forKey: autoSwitchKey)
        os_log("Auto-switch layouts %{public}@", type: .info, enabled ? "enabled" : "disabled")
    }
    
    func isAutoSwitchEnabled() -> Bool {
        return prefs.bool(forKey: autoSwitchKey)
    }
    
    func createDefaultLayoutsIfNeeded() {
        guard layouts.isEmpty else { return }
        
        let onlineDisplayIDs = DisplayConnectionManager.shared.getOnlineDisplayIDs()
        var displayStates: [DisplayState] = []
        for displayID in onlineDisplayIDs {
            displayStates.append(DisplayState(displayID: displayID, isEnabled: true))
        }
        
        var allOnLayout = DisplayLayout(name: NSLocalizedString("All Displays On", comment: "Default layout name"), displayStates: displayStates)
        allOnLayout.isDefault = true
        layouts.append(allOnLayout)
        
        if let builtInID = DisplayConnectionManager.shared.getBuiltInDisplayID() {
            var externalOnlyStates: [DisplayState] = []
            for displayID in onlineDisplayIDs {
                let isBuiltIn = displayID == builtInID
                externalOnlyStates.append(DisplayState(displayID: displayID, isEnabled: !isBuiltIn))
            }
            let externalOnlyLayout = DisplayLayout(name: NSLocalizedString("External Only", comment: "Default layout name"), displayStates: externalOnlyStates)
            layouts.append(externalOnlyLayout)
        }
        
        saveLayouts()
        os_log("Created default layouts", type: .info)
    }
}
