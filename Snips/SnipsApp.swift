//
//  SnipsApp.swift
//  Snips
//
//  Created by Adon Omeri on 9/9/2025.
//

import SwiftUI
import SwiftData

@main
struct SnipsApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
				.modelContainer(
					for: [Folder.self, Snippet.self],
					isAutosaveEnabled: true
				)

        }
    }
}
