//
//  ContentView.swift
//  Snips
//
//  Created by Adon Omeri on 9/9/2025.
//

import SwiftData
import SwiftUI

struct ContentView: View {
	@Environment(\.modelContext) private var modelContext

	@Query(sort: [
		SortDescriptor(\Folder.orderIndex, order: .forward),
		SortDescriptor(\Folder.name, order: .forward),
	]) var folders: [Folder]

	var body: some View {
		NavigationSplitView {
			Rectangle()
				.overlay {
					Text("sections")
				}
			List {}
		} detail: {
			Text("Detail View")
		}
	}
}

#Preview {
	ContentView()
}
