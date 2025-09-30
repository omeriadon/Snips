//  SnippetDetailView.swift
//  Snips
//
//  Created by Adon Omeri on 15/9/2025.
//

import SwiftData
import SwiftUI

struct SnippetDetailView: View {
	@Environment(\.colorScheme) private var colorScheme
	@Environment(\.modelContext) private var modelContext
	@Bindable var snippet: Snippet

	// Tag action (single alert) state
	@State private var tagForAction: String? = nil
	@State private var showingTagAlert = false
	@State private var renameWorkingText: String = ""

	@State var renameTitleText = ""

	// Track editing focus so we only update timestamps on real user edits
	@FocusState private var isTitleFocused: Bool
	@FocusState private var isContentFocused: Bool
	@FocusState private var isNoteFocused: Bool
	@State private var contentDirty = false
	@State private var noteDirty = false
	@State private var previousContent = ""
	@State private var previousNote = ""
	@State private var isEditingTitle = false

	var body: some View {
		ZStack {
			if colorScheme == .dark {
				List {}
					.listStyle(.sidebar)
			} else {
				List {}
					.listStyle(.plain)
			}
			List {
				headerBlock
					.onAppear {
						if snippet.title == "New Snippet" {
							isEditingTitle = true
							isTitleFocused = true
						}
					}
					.listRowSeparator(.hidden)
				Section("Content") { contentEditor }
					.listRowSeparator(.hidden)
				Section("Note") { noteEditor }
					.listRowSeparator(.hidden)
			}
			.listStyle(.inset)
			.scrollContentBackground(.hidden)
		}
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
		.onAppear {
			previousContent = snippet.content
			previousNote = snippet.note
			renameTitleText = snippet.title
		}
		.onChange(of: snippet.id) {
			previousContent = snippet.content
			previousNote = snippet.note
			contentDirty = false
			noteDirty = false
			renameTitleText = snippet.title
			isEditingTitle = false
		}
		.onChange(of: snippet.title, initial: false) { _, newValue in
			if !isEditingTitle {
				renameTitleText = newValue
			}
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
							.animation(.easeInOut, value: snippet.folder?.name)
							.contentTransition(.numericText())
					} else {
						Text("/")
							.font(.title2)
							.opacity(0)
							.animation(.easeInOut, value: snippet.folder?.name)
							.contentTransition(.numericText())
					}
					Group {
						if isEditingTitle {
							TextField("Title", text: $renameTitleText)
								.font(.title)
								.textFieldStyle(.roundedBorder)
								.focused($isTitleFocused)
								.onSubmit { commitTitleEdit() }
								.onChange(of: isTitleFocused) { _, focused in
									if focused == false {
										commitTitleEdit()
									}
								}
								.disabled(snippet.isTrashed)
						} else {
							Text(snippet.title)
								.font(.title)
								.foregroundStyle(snippet.isTrashed ? .secondary : .primary)
								.onTapGesture {
									beginTitleEdit()
								}
								.animation(.easeInOut, value: snippet.title)
								.contentTransition(.numericText())
						}
					}
				}
				Spacer()
				VStack(alignment: .trailing, spacing: 6) {
					Text(
						"Updated: \(snippet.updatedAt, format: .dateTime.year().month().day().hour().minute())"
					)
					.font(.footnote)
					.foregroundStyle(.secondary)
					.animation(.easeInOut, value: snippet.updatedAt)
					.contentTransition(.numericText())

					Picker("", selection: $snippet.type) {
						ForEach(SnippetType.allCases, id: \.self) { type in
							Label(type.title, systemImage: type.symbol)
								.tint(type.color)
								.tag(type)
						}
					}
					.pickerStyle(.menu)
				}
			}
			ScrollView(.horizontal, showsIndicators: false) {
				HStack(spacing: 6) {
					if snippet.tags.isEmpty {
						Text("No tags")
							.font(.caption)
							.foregroundStyle(.tertiary)
					}
					ForEach(snippet.tags, id: \.self) { tag in
						TagChip(tag: tag) {
							triggerTagAction(tag)
						}
						.glassEffect(.clear)
					}
					Button {
						triggerAddTagAction()
					} label: {
						Image(systemName: "plus")
					}
					.buttonStyle(.glassProminent)
					.buttonBorderShape(.circle)
				}
				.padding(.vertical, 2)
			}
			.scrollBounceBehavior(.basedOnSize)
		}
	}

	private var contentEditor: some View {
		TextEditor(text: $snippet.content)
			.id(snippet.id)
			.scrollContentBackground(.hidden)
			.frame(minHeight: 140)
			.focused($isContentFocused)
			.onChange(of: snippet.content, initial: false) { _, newValue in
				guard !snippet.isTrashed else { return }
				if isContentFocused, newValue != previousContent {
					previousContent = newValue
					contentDirty = true
				}
			}
			.onChange(of: isContentFocused) { _, focused in
				if focused == false, contentDirty, !snippet.isTrashed {
					contentDirty = false
					contentChanged()
				}
			}
			.disabled(snippet.isTrashed)
		#if !os(iOS)
			.padding(6)
			.background(.thinMaterial)
			.clipShape(RoundedRectangle(cornerRadius: 15))
		#endif
	}

	private var noteEditor: some View {
		TextEditor(text: $snippet.note)
			.id(snippet.id)
			.scrollContentBackground(.hidden)
			.frame(minHeight: 80)
			.focused($isNoteFocused)
			.onChange(of: snippet.note, initial: false) { _, newValue in
				guard !snippet.isTrashed else { return }
				if isNoteFocused, newValue != previousNote {
					previousNote = newValue
					noteDirty = true
				}
			}
			.onChange(of: isNoteFocused) { _, focused in
				if focused == false, noteDirty, !snippet.isTrashed {
					noteDirty = false
					contentChanged()
				}
			}
			.disabled(snippet.isTrashed)
		#if !os(iOS)
			.padding(6)
			.background(.thinMaterial)
			.clipShape(RoundedRectangle(cornerRadius: 15))
		#endif
	}

	private var toolbarContent: some ToolbarContent {
		ToolbarItem(placement: .primaryAction) {
			Button { /* bookmark placeholder */ } label: { Label("bookmark", systemImage: "bookmark") }
		}
	}

	// MARK: - Tag Actions

	private var tagAlertTitle: String { tagForAction == nil ? "New Tag" : "Tag: \(tagForAction!)" }

	private func beginTitleEdit() {
		guard !snippet.isTrashed else { return }
		renameTitleText = snippet.title
		isEditingTitle = true
		DispatchQueue.main.async {
			isTitleFocused = true
		}
	}

	private func commitTitleEdit() {
		let trimmed = renameTitleText.trimmingCharacters(in: .whitespacesAndNewlines)
		defer {
			renameTitleText = snippet.title
			isEditingTitle = false
			isTitleFocused = false
		}
		guard !snippet.isTrashed else { return }
		guard !trimmed.isEmpty else { return }
		guard trimmed != snippet.title else { return }
		snippet.title = trimmed
		withAnimation(.interactiveSpring(response: 0.3, dampingFraction: 0.85)) {
			snippet.updatedAt = .now
		}
		try? modelContext.save()
	}

	private func contentChanged() {
		withAnimation(.interactiveSpring(response: 0.3, dampingFraction: 0.85)) {
			snippet.updatedAt = .now
		}
		try? modelContext.save()
		previousContent = snippet.content
		previousNote = snippet.note
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
