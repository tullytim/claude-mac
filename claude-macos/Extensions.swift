//
//  Extensions.swift
//  claude-macos
//
//  Created by Tim Tully on 7/16/24.
//

import Foundation
import Cocoa
import AppKit

class FramelessWindow: NSWindow {
    override var canBecomeKey: Bool {
        return true
    }

    override var canBecomeMain: Bool {
        return true
    }
}

extension Notification.Name {
    static let keyDownEvent = Notification.Name("antKeyDownEvent")
    static let showSettingsEvent = Notification.Name("showSettingsEvent")
    static let bringToFront = Notification.Name("bringToFront")
}
extension String {
    func makeHTMLfriendly() -> String {
        var finalString = ""
        for char in self {
            for scalar in String(char).unicodeScalars {
                finalString.append("&#\(scalar.value)")
            }
        }
        return finalString
    }
}

extension NSColor {
    convenience init(hex: String, alpha: CGFloat = 1.0) {
        var hexFormatted: String = hex.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        hexFormatted = hexFormatted.replacingOccurrences(of: "#", with: "")
        
        var rgbValue: UInt64 = 0
        Scanner(string: hexFormatted).scanHexInt64(&rgbValue)
        
        let red = CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0
        let green = CGFloat((rgbValue & 0x00FF00) >> 8) / 255.0
        let blue = CGFloat(rgbValue & 0x0000FF) / 255.0
        
        self.init(red: red, green: green, blue: blue, alpha: alpha)
    }
}

extension NSImage {
    func imageWithRoundedCorners(radius: CGFloat) -> NSImage {
        let size = self.size
        let bounds = NSRect(origin: .zero, size: size)
        
        let image = NSImage(size: size)
        image.lockFocus()
        
        let context = NSGraphicsContext.current
        context?.imageInterpolation = .high
        
        let path = NSBezierPath(roundedRect: bounds, xRadius: radius, yRadius: radius)
        path.windingRule = .evenOdd
        path.addClip()
        
        self.draw(in: bounds, from: bounds, operation: .sourceOver, fraction: 1.0)
        
        image.unlockFocus()
        
        return image
    }
}

class CustomHeaderCell: NSTableHeaderCell {
    override func draw(withFrame cellFrame: NSRect, in controlView: NSView) {
        guard let image = self.image else {
            super.draw(withFrame: cellFrame, in: controlView)
            return
        }

        // Define the size for the image
        let imageWidth: CGFloat = 80 // Adjust the width as needed
        let imageHeight: CGFloat = 20 // Adjust the height as needed
        
        // Calculate the position to left align the image
        let imageRect = NSRect(x: cellFrame.origin.x + 5, // Adding a small padding from the left
                               y: cellFrame.origin.y + (cellFrame.size.height - imageHeight) / 2,
                               width: imageWidth,
                               height: imageHeight)
        
        // Draw the image
        image.draw(in: imageRect)
    }
}



class CustomTableView: NSTableView {

    var contextMenu: NSMenu?

    override func mouseDown(with event: NSEvent) {
        if event.type == .leftMouseDown && event.modifierFlags.contains(.control) {
            rightMouseDown(with: event)
        } else {
            super.mouseDown(with: event)
        }
    }

    override func rightMouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let row = row(at: point)

        if row >= 0 {
            selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
            if let menu = contextMenu {
                NSMenu.popUpContextMenu(menu, with: event, for: self)
            }
        } else {
            super.rightMouseDown(with: event)
        }
    }
}
