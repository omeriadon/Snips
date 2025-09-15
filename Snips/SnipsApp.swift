//
//  SnipsApp.swift
//  Snips
//
//  Created by Adon Omeri on 9/9/2025.
//

import SwiftData
import SwiftUI

@main
struct SnipsApp: App {
	var body: some Scene {
		WindowGroup {
			ContentView()
				.modelContainer(
					for: [Folder.self, Snippet.self],
					isAutosaveEnabled: true
				)
				.tint(Color(red: 0.541, green: 0.506, blue: 1.0)) // purple from app
		}
	}
}
