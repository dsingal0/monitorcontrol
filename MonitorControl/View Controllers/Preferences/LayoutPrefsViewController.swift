//  Copyright © MonitorControl. @JoniVR, @theOneyouseek, @waydabber and others

import Cocoa
import os.log
import Settings

class LayoutPrefsViewController: NSViewController, SettingsPane, NSTableViewDataSource, NSTableViewDelegate {
  let paneIdentifier = Settings.PaneIdentifier(rawValue: "layouts")
  let paneTitle: String = NSLocalizedString("Layouts", comment: "Shown in the main prefs window")
  
  var toolbarItemIcon: NSImage {
    if !DEBUG_MACOS10, #available(macOS 11.0, *) {
      return NSImage(systemSymbolName: "rectangle.on.rectangle", accessibilityDescription: "Layouts")!
    } else {
      return NSImage(named: NSImage.multipleDocumentsName)!
    }
  }
  
  var layoutList: NSTableView!
  var autoSwitchCheckbox: NSButton!
  var deleteButton: NSButton!
  var applyButton: NSButton!
  var setDefaultButton: NSButton!
  var saveButton: NSButton!
  
  override func loadView() {
    let contentView = NSView(frame: NSRect(x: 0, y: 0, width: 600, height: 400))
    
    let scrollView = NSScrollView(frame: NSRect(x: 20, y: 100, width: 560, height: 250))
    scrollView.hasVerticalScroller = true
    scrollView.hasHorizontalScroller = false
    scrollView.borderType = .bezelBorder
    
    layoutList = NSTableView(frame: NSRect(x: 0, y: 0, width: 560, height: 250))
    layoutList.dataSource = self
    layoutList.delegate = self
    let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("LayoutColumn"))
    column.title = NSLocalizedString("Layout Name", comment: "Table column header")
    column.width = 540
    layoutList.addTableColumn(column)
    layoutList.headerView = nil
    
    scrollView.documentView = layoutList
    contentView.addSubview(scrollView)
    
    autoSwitchCheckbox = NSButton(checkboxWithTitle: NSLocalizedString("Auto-switch layouts when displays connect/disconnect", comment: "Checkbox label"), target: self, action: #selector(autoSwitchChanged))
    autoSwitchCheckbox.frame = NSRect(x: 20, y: 70, width: 560, height: 20)
    autoSwitchCheckbox.state = LayoutManager.shared.isAutoSwitchEnabled() ? .on : .off
    contentView.addSubview(autoSwitchCheckbox)
    
    let buttonY: CGFloat = 30
    let buttonWidth: CGFloat = 120
    let buttonHeight: CGFloat = 24
    let spacing: CGFloat = 10
    
    saveButton = NSButton(frame: NSRect(x: 20, y: buttonY, width: buttonWidth, height: buttonHeight))
    saveButton.title = NSLocalizedString("Save Current", comment: "Button")
    saveButton.bezelStyle = .rounded
    saveButton.target = self
    saveButton.action = #selector(saveCurrentLayoutClicked)
    contentView.addSubview(saveButton)
    
    applyButton = NSButton(frame: NSRect(x: 20 + buttonWidth + spacing, y: buttonY, width: buttonWidth, height: buttonHeight))
    applyButton.title = NSLocalizedString("Apply", comment: "Button")
    applyButton.bezelStyle = .rounded
    applyButton.target = self
    applyButton.action = #selector(applyLayoutClicked)
    contentView.addSubview(applyButton)
    
    setDefaultButton = NSButton(frame: NSRect(x: 20 + (buttonWidth + spacing) * 2, y: buttonY, width: buttonWidth, height: buttonHeight))
    setDefaultButton.title = NSLocalizedString("Set Default", comment: "Button")
    setDefaultButton.bezelStyle = .rounded
    setDefaultButton.target = self
    setDefaultButton.action = #selector(setDefaultLayoutClicked)
    contentView.addSubview(setDefaultButton)
    
    deleteButton = NSButton(frame: NSRect(x: 20 + (buttonWidth + spacing) * 3, y: buttonY, width: buttonWidth, height: buttonHeight))
    deleteButton.title = NSLocalizedString("Delete", comment: "Button")
    deleteButton.bezelStyle = .rounded
    deleteButton.target = self
    deleteButton.action = #selector(deleteLayoutClicked)
    contentView.addSubview(deleteButton)
    
    self.view = contentView
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    self.updateButtons()
  }
  
  @objc func loadLayoutList() {
    guard self.layoutList != nil else { return }
    self.layoutList.reloadData()
  }
  
  func numberOfRows(in _: NSTableView) -> Int {
    return LayoutManager.shared.layouts.count
  }
  
  func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
    let layout = LayoutManager.shared.layouts[row]
    let cellId = NSUserInterfaceItemIdentifier("LayoutCell")
    
    var cell: NSTableCellView
    if let existingCell = tableView.makeView(withIdentifier: cellId, owner: nil) as? NSTableCellView {
      cell = existingCell
    } else {
      cell = NSTableCellView()
      cell.identifier = cellId
      
      let textField = NSTextField()
      textField.isEditable = false
      textField.isBordered = false
      textField.drawsBackground = false
      textField.translatesAutoresizingMaskIntoConstraints = false
      cell.addSubview(textField)
      cell.textField = textField
      
      NSLayoutConstraint.activate([
        textField.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 5),
        textField.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
      ])
    }
    
    var layoutName = layout.name
    if layout.isDefault {
      layoutName += " (\(NSLocalizedString("Default", comment: "Default layout indicator")))"
    }
    if LayoutManager.shared.activeLayout?.id == layout.id {
      layoutName += " ✓"
    }
    cell.textField?.stringValue = layoutName
    
    return cell
  }
  
  func tableViewSelectionDidChange(_ notification: Notification) {
    self.updateButtons()
  }
  
  func updateButtons() {
    let hasSelection = self.layoutList != nil && self.layoutList.selectedRow >= 0 && self.layoutList.selectedRow < LayoutManager.shared.layouts.count
    self.deleteButton?.isEnabled = hasSelection
    self.applyButton?.isEnabled = hasSelection
    self.setDefaultButton?.isEnabled = hasSelection
  }
  
  @objc func autoSwitchChanged(_ sender: NSButton) {
    LayoutManager.shared.setAutoSwitchEnabled(sender.state == .on)
  }
  
  @objc func saveCurrentLayoutClicked(_ sender: NSButton) {
    let alert = NSAlert()
    alert.messageText = NSLocalizedString("Save Current Layout", comment: "Alert title")
    alert.informativeText = NSLocalizedString("Enter a name for this layout:", comment: "Alert message")
    alert.addButton(withTitle: NSLocalizedString("Save", comment: "Button"))
    alert.addButton(withTitle: NSLocalizedString("Cancel", comment: "Button"))
    
    let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
    textField.stringValue = NSLocalizedString("My Layout", comment: "Default layout name")
    alert.accessoryView = textField
    
    let response = alert.runModal()
    if response == .alertFirstButtonReturn {
      let name = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !name.isEmpty else { return }
      _ = LayoutManager.shared.saveCurrentLayout(name: name)
      self.loadLayoutList()
      menuHandler.updateMenus()
    }
  }
  
  @objc func deleteLayoutClicked(_ sender: NSButton) {
    let selectedRow = self.layoutList.selectedRow
    guard selectedRow >= 0 && selectedRow < LayoutManager.shared.layouts.count else { return }
    
    let layout = LayoutManager.shared.layouts[selectedRow]
    
    let alert = NSAlert()
    alert.messageText = NSLocalizedString("Delete Layout", comment: "Alert title")
    alert.informativeText = String(format: NSLocalizedString("Are you sure you want to delete the layout '%@'?", comment: "Alert message"), layout.name)
    alert.addButton(withTitle: NSLocalizedString("Delete", comment: "Button"))
    alert.addButton(withTitle: NSLocalizedString("Cancel", comment: "Button"))
    alert.alertStyle = .warning
    
    let response = alert.runModal()
    if response == .alertFirstButtonReturn {
      LayoutManager.shared.deleteLayout(layout)
      self.loadLayoutList()
      self.updateButtons()
      menuHandler.updateMenus()
    }
  }
  
  @objc func applyLayoutClicked(_ sender: NSButton) {
    let selectedRow = self.layoutList.selectedRow
    guard selectedRow >= 0 && selectedRow < LayoutManager.shared.layouts.count else { return }
    
    let layout = LayoutManager.shared.layouts[selectedRow]
    do {
      try LayoutManager.shared.applyLayout(layout)
      self.loadLayoutList()
      menuHandler.updateMenus()
    } catch {
      let alert = NSAlert()
      alert.messageText = NSLocalizedString("Failed to apply layout", comment: "Alert title")
      alert.informativeText = error.localizedDescription
      alert.runModal()
    }
  }
  
  @objc func setDefaultLayoutClicked(_ sender: NSButton) {
    let selectedRow = self.layoutList.selectedRow
    guard selectedRow >= 0 && selectedRow < LayoutManager.shared.layouts.count else { return }
    
    let layout = LayoutManager.shared.layouts[selectedRow]
    LayoutManager.shared.setDefaultLayout(layout)
    self.loadLayoutList()
  }
}
