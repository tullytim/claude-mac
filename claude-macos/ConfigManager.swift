//
//  ConfigManager.swift
//  claude
//
//  Created by Tim Tully on 3/15/24.
//

import Foundation

class ConfigManager {
    private var settings: [String: Any] = [:]

    init?() {
        guard let configPath = Bundle.main.path(forResource: "Config", ofType: "plist"),
              let configValues = NSDictionary(contentsOfFile: configPath) as? [String: Any] else {
            return nil
        }
        settings = configValues
    }

    func value(forKey key: String) -> Any? {
        return settings[key]
    }
}
