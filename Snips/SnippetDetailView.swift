//
//  SnippetDetailView.swift
//  Snips
//
//  Created by Adon Omeri on 15/9/2025.
//

import SwiftUI

struct SnippetDetailView: View {

	let snippet: Snippet

    var body: some View {
		List {

			GroupBox {
				HStack {
					Text(snippet.title)
						.font(.title)
					Spacer()
					Image(systemName: snippet.type.symbol)
						.foregroundStyle(.black)
						.padding(8)
						.glassEffect(.clear.tint(snippet.type.color))
				}
				.padding(8)
			}



		}
			.listStyle(.sidebar)
			.scrollDisabled(true)
			.toolbar {
				Button {} label: {
					Label("bookmark", systemImage: "bookmark")
				}
			}
    }
}

#Preview {
	SnippetDetailView(
		snippet: Snippet(
			id: UUID(),
			title: "title",
			type: .command,
			tags: ["tag", "two"],
			updatedAt: .now,
			folder: nil,
			content: "content",
			note: "note"
		)
	)
}
