//
//  AppDelegate.swift
//  claude-macos
//
//  Created by Tim Tully on 7/15/24.
//

import Cocoa
import Mixpanel

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate, NSMenuItemValidation {
    
    var mainWindowController: NSWindowController?
    
    var statusItem: NSStatusItem?
    var eventTap: CFMachPort?
    static var searchBarShowing:Bool = false
    static var window: FramelessWindow!
    var menuWindowOnTop:NSMenuItem?
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        setupTracking()
        setupStatusBar()
        requestAccessibilityPermissions()
        setupGlobalKeyListener()
    }
    
    func setupTracking(){
        Mixpanel.initialize(token: "1985bb9888363741e7aad5c9eccd5157")
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        if let eventTap = eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }
    }
    
    func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            
            let buttonImage = NSImage(named:"ant2")
            let rounded = buttonImage?.imageWithRoundedCorners(radius: 8)
            button.image = rounded
            button.action = #selector(showMenu)
            button.target = self
        }
    }
    
    @objc func showMenu() {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Show Claude", action: #selector(menuShowClaude), keyEquivalent: "1"))
        let chatMenu = NSMenuItem(title: "Show Chat Bar", action: #selector(menuShowChat), keyEquivalent: " ")
        chatMenu.keyEquivalentModifierMask = [.control]
        chatMenu.target = self
        menu.addItem(chatMenu)
        menu.addItem(NSMenuItem(title: "Settings", action: #selector(showSettings), keyEquivalent: "2"))
        menu.addItem(NSMenuItem.separator())
        menuWindowOnTop = NSMenuItem(title: "Keep Window On Top", action: #selector(menuKeepOnTop), keyEquivalent: "3")
        menu.addItem(menuWindowOnTop!)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Check For Updates", action: #selector(menuCheckUpdates), keyEquivalent: "4"))
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(menuQuitApp), keyEquivalent: "q"))
        statusItem?.menu = menu
        statusItem?.button?.performClick(nil) // Show the menu
    }
    
    @objc func menuShowClaude(){
        DispatchQueue.main.async{
            for window in NSApplication.shared.windows {
                if !window.isKind(of: NSClassFromString("NSStatusBarWindow")!) && !window.isKind(of:NSClassFromString("NSPopupMenuWindow")!){
                    window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
                    window.makeKeyAndOrderFront(nil)
                    window.orderFrontRegardless()
                    window.makeKey()
                    
                }
            }
        }
        NotificationCenter.default.post(name:.bringToFront, object: nil)
    }
    
    @objc func menuShowChat() {
        AppDelegate.controlSpacePressed()
    }
    
    @objc func showSettings() {
        NotificationCenter.default.post(name:.showSettingsEvent, object: nil)
    }
    
    func bringAllFront(){
        DispatchQueue.main.async{
            for window in NSApplication.shared.windows {
                if !window.isKind(of: NSClassFromString("NSStatusBarWindow")!) && !window.isKind(of:NSClassFromString("NSPopupMenuWindow")!){
                    window.level = .screenSaver
                    window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
                    window.makeKeyAndOrderFront(nil)
                    if(self.menuWindowOnTop?.state == .off){
                        self.menuWindowOnTop?.state = .on // Initially unchecked
                    }
                    else{
                        self.menuWindowOnTop?.state = .off
                        window.level = .normal
                    }
                }
            }
        }
    }
    
    @objc func menuKeepOnTop(){
        bringAllFront()
    }
    
    @objc func menuCheckUpdates(){
        let alert = NSAlert()
        alert.messageText = "No update"
        alert.informativeText = "No update for Claude yet. Thanks for using Claude!"
        alert.alertStyle = .warning // You can choose between .warning, .informational, or .critical
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    @objc func menuQuitApp() {
        NSApplication.shared.terminate(self)
    }
    
    func requestAccessibilityPermissions() {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true]
        let accessEnabled = AXIsProcessTrustedWithOptions(options)
        if !accessEnabled {
            print("Accessibility permissions not granted.")
        }
    }
    
    func setupGlobalKeyListener() {
        let eventMask: CGEventMask = (1 << CGEventType.keyDown.rawValue)
        
        let callback: CGEventTapCallBack = { (proxy, type, event, refcon) in
            guard type == .keyDown else { return Unmanaged.passUnretained(event) }
            let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
            let flags = event.flags.rawValue & 0xFFFF0000
            let controlFlag = CGEventFlags.maskControl.rawValue & 0xFFFF0000
            
            if keyCode == 49 && flags == controlFlag { // 49 is the keycode for the Space bar
                AppDelegate.controlSpacePressed()
            }
            
            return Unmanaged.passUnretained(event)
        }
        
        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: callback,
            userInfo: nil
        )
        
        if let eventTap = eventTap {
            let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
            CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
            CGEvent.tapEnable(tap: eventTap, enable: true)
            print("Event tap created successfully")
        } else {
            print("Failed to create event tap.")
        }
    }
    
    @objc static func bringWindowToFront() {
        if let window = AppDelegate.window {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
        }
    }
    
    static func controlSpacePressed() {
        Mixpanel.mainInstance().track(event:"control-space")
        if !AppDelegate.searchBarShowing {
            let mainViewController = SearchViewController()
            
            window = FramelessWindow(
                contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            window.contentViewController = mainViewController
            window.isOpaque = false
            window.backgroundColor = NSColor.clear
            window.hasShadow = true // Optional: Add shadow to the window
            
            // round corners
            window.contentView?.wantsLayer = true
            window.contentView?.layer?.cornerRadius = 10
            window.contentView?.layer?.masksToBounds = true
            window.contentView?.layer?.borderWidth = 1
            window.contentView?.layer?.borderColor = NSColor.lightGray.cgColor
            window.contentView?.layer?.backgroundColor = NSColor.white.cgColor
            window.contentView?.layer?.shadowOpacity = 0.5
            window.contentView?.layer?.shadowRadius = 10
            window.makeKeyAndOrderFront(nil)
            window.center()
            bringWindowToFront()
            AppDelegate.searchBarShowing = true
        }
        else{
            AppDelegate.searchBarShowing = false
            
            if(window != nil){
                window?.orderOut(nil)
            }
            window = nil
        }
    }
    
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        return true
    }
}


