//  Copyright © MonitorControl. @JoniVR, @theOneyouseek, @waydabber and others

import AppKit
import Foundation
import CoreGraphics

struct DisplayIdentifier: Codable, Hashable {
    let vendorNumber: UInt32?
    let modelNumber: UInt32?
    let serialNumber: UInt32?
    let name: String
    
    init(vendorNumber: UInt32?, modelNumber: UInt32?, serialNumber: UInt32?, name: String) {
        self.vendorNumber = vendorNumber
        self.modelNumber = modelNumber
        self.serialNumber = serialNumber
        self.name = name
    }
    
    init(displayID: CGDirectDisplayID) {
        self.vendorNumber = CGDisplayVendorNumber(displayID)
        self.modelNumber = CGDisplayModelNumber(displayID)
        self.serialNumber = CGDisplaySerialNumber(displayID)
        if let screen = NSScreen.screens.first(where: { ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID) == displayID }) {
            if #available(macOS 10.15, *) {
                self.name = screen.localizedName
            } else {
                self.name = "Display \(displayID)"
            }
        } else {
            self.name = "Display \(displayID)"
        }
    }
    
    func matches(displayID: CGDirectDisplayID) -> Bool {
        let otherVendor = CGDisplayVendorNumber(displayID)
        let otherModel = CGDisplayModelNumber(displayID)
        let otherSerial = CGDisplaySerialNumber(displayID)
        
        if let v = vendorNumber, v == otherVendor,
           let m = modelNumber, m == otherModel {
            if let s = serialNumber {
                return s == otherSerial
            }
            return true
        }
        return false
    }
}

struct DisplayState: Codable, Hashable {
    let displayIdentifier: DisplayIdentifier
    var isEnabled: Bool
    var isBuiltIn: Bool
    
    init(displayIdentifier: DisplayIdentifier, isEnabled: Bool, isBuiltIn: Bool) {
        self.displayIdentifier = displayIdentifier
        self.isEnabled = isEnabled
        self.isBuiltIn = isBuiltIn
    }
    
    init(displayID: CGDirectDisplayID, isEnabled: Bool) {
        self.displayIdentifier = DisplayIdentifier(displayID: displayID)
        self.isEnabled = isEnabled
        self.isBuiltIn = CGDisplayIsBuiltin(displayID) != 0
    }
}

struct DisplayLayout: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String
    var displayStates: [DisplayState]
    var isDefault: Bool
    var lastUsed: Date?
    var autoSwitch: Bool
    
    init(id: UUID = UUID(), name: String, displayStates: [DisplayState], isDefault: Bool = false, autoSwitch: Bool = true) {
        self.id = id
        self.name = name
        self.displayStates = displayStates
        self.isDefault = isDefault
        self.lastUsed = nil
        self.autoSwitch = autoSwitch
    }
    
    func matches(connectedDisplayIDs: [CGDirectDisplayID]) -> Bool {
        let connectedIdentifiers = connectedDisplayIDs.map { DisplayIdentifier(displayID: $0) }
        let layoutIdentifiers = displayStates.map { $0.displayIdentifier }
        
        for layoutState in displayStates {
            let hasMatch = connectedIdentifiers.contains { connectedId in
                layoutState.displayIdentifier.vendorNumber == connectedId.vendorNumber &&
                layoutState.displayIdentifier.modelNumber == connectedId.modelNumber
            }
            if !hasMatch && layoutState.isEnabled {
                return false
            }
        }
        
        for connectedId in connectedIdentifiers {
            let isInLayout = layoutIdentifiers.contains { layoutId in
                layoutId.vendorNumber == connectedId.vendorNumber &&
                layoutId.modelNumber == connectedId.modelNumber
            }
            if !isInLayout {
                return false
            }
        }
        
        return true
    }
    
    func getDisplayState(for displayID: CGDirectDisplayID) -> DisplayState? {
        for state in displayStates {
            if state.displayIdentifier.matches(displayID: displayID) {
                return state
            }
        }
        return nil
    }
    
    mutating func updateLastUsed() {
        self.lastUsed = Date()
    }
}
