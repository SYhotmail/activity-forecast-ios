//
//  Logger+Ext.swift
//  ActivityForecast
//
//  Created by Siarhei Yakushevich on 05/11/2026.
//
import os
import Foundation

extension Logger {
    init(category: String) {
        self.init(subsystem: Bundle.main.bundleIdentifier ?? "ActivityForecast", category: category)
    }
}
