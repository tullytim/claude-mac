//
//  SearchViewController.swift
//  claude-macos
//
//  Created by Tim Tully on 7/16/24.
//

import Foundation
import Cocoa

class SearchViewController: NSViewController, NSSearchFieldDelegate {

    override func loadView() {
        self.view = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 40))
        self.view.wantsLayer = true
        self.view.layer?.backgroundColor = NSColor.white.cgColor

        // Example content
        //let label = NSTextField(labelWithString: "")
        let label = NSSearchField(labelWithString: "")
        label.frame = NSRect(x: 50, y: 10, width: 300, height: 20)
        label.isEditable = true
        label.placeholderString = "Search Claude Here..."
        label.alignment = .center
        self.view.addSubview(label)
        label.delegate = self
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        // Make the window background fully opaque
        self.view.window?.isOpaque = false
        self.view.window?.backgroundColor = NSColor.clear
    }
    
    func controlTextDidEndEditing(_ obj: Notification) {
        guard let textField = obj.object as? NSTextField else { return }
        if let event = NSApp.currentEvent  {
            if event.keyCode == 36 {
                let searchText = textField.stringValue
                //doQuery(q:searchText)
                NotificationCenter.default.post(name: .RUN_SEARCH, object: nil, userInfo: ["qt": searchText])
                bringAllWindowsToFront()
            }
        }
    }
    
    func bringAllWindowsToFront() {
            for window in NSApplication.shared.windows {
                window.makeKeyAndOrderFront(nil)
            }
        }
}
