//
//  SnippetDetailView.swift
//  Snips
//
//  Created by Adon Omeri on 15/9/2025.
//

import SwiftData
import SwiftUI

struct SnippetDetailView: View {
	@Environment(\.modelContext) private var modelContext
	@Bindable var snippet: Snippet

	// Tag action (single alert) state
	@State private var tagForAction: String? = nil
	@State private var showingTagAlert = false
	@State private var renameWorkingText: String = ""

	var body: some View {
		List {
			headerBlock
			Section("Content") { contentEditor }
			Section("Note") { noteEditor }
		}
		.listStyle(.sidebar)
		.toolbar { toolbarContent }
		.alert(tagAlertTitle, isPresented: $showingTagAlert) {
			TextField("Tag Name", text: $renameWorkingText)
			Button("Save") { commitRename() }
			if tagForAction != nil {
				Button("Delete", role: .destructive) {
					if let t = tagForAction { removeTag(t) }
				}
			}
			Button("Cancel", role: .cancel) { clearTagAlert() }
		} message: {
			Text(tagForAction == nil ? "Create a new tag." : "Rename or delete this tag.")
		}
	}

	private var headerBlock: some View {
		VStack(alignment: .leading, spacing: 8) {
			HStack(alignment: .top) {
				VStack(alignment: .leading, spacing: 4) {
					if let name = snippet.folder?.name {
						Text("\(name) /")
							.font(.title2)
							.foregroundStyle(.quaternary)
					}
					Text(snippet.title)
						.font(.title)
				}
				Spacer()
				VStack(alignment: .trailing, spacing: 6) {
					Text("Updated: \(snippet.updatedAt, format: .dateTime.year().month().day())")
						.font(.footnote)
						.foregroundStyle(.secondary)
					Image(systemName: snippet.type.symbol)
						.foregroundStyle(.black)
						.padding(8)
						.glassEffect(.clear.tint(snippet.type.color))
				}
			}
			ScrollView(.horizontal, showsIndicators: false) {
				HStack(spacing: 6) {
					if snippet.tags.isEmpty {
						Text("No tags")
							.font(.caption)
							.foregroundStyle(.tertiary)
							.transition(.opacity)
					}
					ForEach(snippet.tags, id: \.self) { tag in
						TagChip(tag: tag) {
							withAnimation {
								triggerTagAction(tag)
							}
						}
						.glassEffect(.clear)
						.transition(.move(edge: .leading).combined(with: .opacity))
					}
					Button {
						withAnimation {
							triggerAddTagAction()
						}
					} label: {
						Image(systemName: "plus")
					}
					.buttonStyle(.glassProminent)
					.buttonBorderShape(.circle)
					.transition(.scale.combined(with: .opacity))
				}
				.padding(.top, 2)
			}
			.scrollBounceBehavior(.basedOnSize)
			.animation(.easeInOut, value: snippet.tags)
		}
	}

	private var contentEditor: some View {
		TextEditor(text: $snippet.content)
			.scrollContentBackground(.hidden)
			.frame(minHeight: 140)
			.onChange(of: snippet.content) { contentChanged() }
	}

	private var noteEditor: some View {
		TextEditor(text: $snippet.note)
			.scrollContentBackground(.hidden)
			.frame(minHeight: 120)
			.onChange(of: snippet.note) { contentChanged() }
	}

	private var toolbarContent: some ToolbarContent {
		ToolbarItem(placement: .primaryAction) {
			Button { /* bookmark placeholder */ } label: { Label("bookmark", systemImage: "bookmark") }
		}
	}

	// MARK: - Tag Actions

	private var tagAlertTitle: String { tagForAction == nil ? "New Tag" : "Tag: \(tagForAction!)" }

	private func contentChanged() {
		snippet.updatedAt = .now
		try? modelContext.save()
	}

	private func triggerTagAction(_ tag: String) {
		tagForAction = tag
		renameWorkingText = tag
		showingTagAlert = true
	}

	private func clearTagAlert() {
		tagForAction = nil
		renameWorkingText = ""
	}

	private func commitRename() {
		let trimmed = renameWorkingText.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !trimmed.isEmpty else { clearTagAlert(); return }
		if let original = tagForAction { // rename existing
			guard trimmed != original, !snippet.tags.contains(trimmed) else { clearTagAlert(); return }
			if let idx = snippet.tags.firstIndex(of: original) {
				snippet.tags[idx] = trimmed
				contentChanged()
			}
		} else { // create
			guard !snippet.tags.contains(trimmed) else { clearTagAlert(); return }
			withAnimation(.easeInOut(duration: 0.2)) { snippet.tags.append(trimmed) }
			contentChanged()
		}
		clearTagAlert()
	}

	private func triggerAddTagAction() {
		tagForAction = nil
		renameWorkingText = ""
		showingTagAlert = true
	}

	private func removeTag(_ tag: String) {
		guard let idx = snippet.tags.firstIndex(of: tag) else { return }
		snippet.tags.remove(at: idx)
		contentChanged()
	}
}

private struct TagChip: View {
	let tag: String
	let action: () -> Void

	var body: some View {
		Text(tag)
			.font(.caption)
			.lineLimit(1)
			.padding(.vertical, 4)
			.padding(.horizontal, 8)
			.onTapGesture { action() }
	}
}

#Preview {
	@Previewable @State var snippet = Snippet(
		id: UUID(),
		title: "title",
		type: .command,
		tags: ["tag", "two"],
		updatedAt: .now,
		folder: Folder(id: UUID(), name: "folder name", orderIndex: 0, snippets: []),
		content: "content",
		note: "note"
	)
	SnippetDetailView(snippet: snippet)
}
