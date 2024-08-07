//
//  PreferencesWindowController.swift
//  claude-macos
//
//  Created by Tim Tully on 7/16/24.
//

import Foundation
import Cocoa

class PreferencesWindowController: NSWindowController, NSMenuItemValidation {
    
    static let shared = PreferencesWindowController(windowNibName: "PreferencesWindow")
    override func windowDidLoad() {
        super.windowDidLoad()
        // Add any additional setup after loading the window.
    }
    
    @IBAction func applyPreferences(_ sender: Any) {
        // Code to handle applying preferences
    }
    
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {          
        return true
    }
}
