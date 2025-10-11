//  SnippetDetailView.swift
//  Snips
//
//  Created by Adon Omeri on 15/9/2025.
//

import CodeEditor
import SwiftData
import SwiftUI
#if os(macOS)
	import SwiftShell_Function
#endif

struct SnippetDetailView: View {
	@Environment(\.colorScheme) private var colorScheme
	@Environment(\.modelContext) private var modelContext
	@Environment(\.undoManager) private var undoManager
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

	@State private var contentOriginalValue = ""
	@State private var noteOriginalValue = ""

	@State private var showingDeleteConfirmation = false

	@State private var typeSelection: SnippetType = .plainText

	@State private var showUnableToActionAlert = false
	@State private var unableToActionMessage = ""
	@State private var unableToActionTitle = ""

	@State private var showCommandSheet = false

	// MARK: - body

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
							if !snippet.isTrashed {
								isEditingTitle = true
								isTitleFocused = true
							}
						}
					}
					.listRowSeparator(.hidden)
				Section { contentEditor } header: {
					HStack {
						Text("Content")
						Spacer()
						if snippet.type == .command {
							Text("Put each command on a new line.")
						} else if snippet.type == .link {
							Text("Do not include `https://` in the link.")
						}
					}
				}
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
		.confirmationDialog(
			"Move to Recycle Bin?",
			isPresented: $showingDeleteConfirmation,
			titleVisibility: .visible
		) {
			Button("Move to Recycle Bin", role: .destructive) {
				moveSnippetToTrash()
			}
			Button("Cancel", role: .cancel) {
				showingDeleteConfirmation = false
			}
		} message: {
			Text("'\(snippet.title)' will move to the Recycle Bin. You can restore it later from there.")
		}
		.onAppear {
			previousContent = snippet.content
			previousNote = snippet.note
			renameTitleText = snippet.title
			contentOriginalValue = snippet.content
			noteOriginalValue = snippet.note
			typeSelection = snippet.type
		}
		.onChange(of: snippet.id) {
			previousContent = snippet.content
			previousNote = snippet.note
			contentDirty = false
			noteDirty = false
			renameTitleText = snippet.title
			isEditingTitle = false
			contentOriginalValue = snippet.content
			noteOriginalValue = snippet.note
			typeSelection = snippet.type
		}
		.onChange(of: snippet.title, initial: false) { _, newValue in
			if !isEditingTitle {
				renameTitleText = newValue
			}
		}
		.onChange(of: snippet.type, initial: false) { _, newValue in
			typeSelection = newValue
		}
	}

	// MARK: - Header Block

	private var headerBlock: some View {
		VStack(alignment: .leading, spacing: 8) {
			HStack(alignment: .top) {
				VStack(alignment: .leading, spacing: 4) {
					if let name = snippet.folder?.name {
						Text("\(name) /")
							.font(.title2)
							.foregroundStyle(.quaternary)
					} else {
						Text("/")
							.font(.title2)
							.opacity(0)
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

					Picker("", selection: $typeSelection) {
						ForEach(SnippetType.allCases, id: \.self) { type in
							Label(type.title, systemImage: type.symbol)
								.tint(type.color)
								.tag(type)
						}
					}
					.pickerStyle(.menu)
					.onChange(of: typeSelection) { _, newValue in
						commitTypeChange(newValue)
					}
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

	// MARK: - Content Editor

	private var contentEditor: some View {
		Group {
			if snippet.type == .code {
				if colorScheme == .dark {
					CodeEditor(
						source: $snippet.content,
						language: snippet.language,
						theme: CodeEditor.ThemeName(rawValue: "atelier-dune-dark"),
						allowsUndo: true
					)
					.clipShape(RoundedRectangle(cornerRadius: 9))

				} else {
					CodeEditor(
						source: $snippet.content,
						language: snippet.language,
						theme: CodeEditor.ThemeName(rawValue: "atelier-dune"),
						allowsUndo: true
					)
					.clipShape(RoundedRectangle(cornerRadius: 9))
				}

			} else if snippet.type == .command {
				if colorScheme == .dark {
					CodeEditor(
						source: $snippet.content,
						language: CodeEditor.Language.bash,
						theme: CodeEditor.ThemeName(rawValue: "atelier-dune-dark"),
						allowsUndo: true
					)
					.clipShape(RoundedRectangle(cornerRadius: 9))

				} else {
					CodeEditor(
						source: $snippet.content,
						language: CodeEditor.Language.bash,
						theme: CodeEditor.ThemeName(rawValue: "atelier-dune"),
						allowsUndo: true
					)
					.clipShape(RoundedRectangle(cornerRadius: 9))
				}

			} else {
				TextEditor(text: $snippet.content)
					.fontWidth(.standard)
					.fontDesign(.rounded)
					.font(.title3)
			}
		}
		.alert(
			unableToActionTitle, isPresented: $showUnableToActionAlert
		) {
			Button {} label: {
				Text("OK")
			}
		} message: {
			Text(unableToActionMessage)
		}

		// MARK: - Command Sheet

		.sheet(isPresented: $showCommandSheet) {
			CommandRunnerSheet(snippet: snippet)
		}
		.id(snippet.id)
		.scrollContentBackground(.hidden)
		.frame(minHeight: snippet.type == .code ? 400 : 250, maxHeight: .infinity)
		.focused($isContentFocused)
		.onChange(of: snippet.content, initial: false) { _, newValue in
			guard !snippet.isTrashed else { return }
			if isContentFocused {
				if newValue != previousContent {
					previousContent = newValue
					contentDirty = true
				}
			} else {
				previousContent = newValue
			}
		}
		.onChange(of: isContentFocused) { _, focused in
			if focused {
				contentOriginalValue = snippet.content
			} else if contentDirty, !snippet.isTrashed {
				finalizeContentEdit()
			}
		}
		.disabled(snippet.isTrashed)
		.padding(6)
		.background(.ultraThinMaterial)
		.clipShape(RoundedRectangle(cornerRadius: 15))
	}

	// MARK: - Note Editor

	private var noteEditor: some View {
		TextEditor(text: $snippet.note)
			.id(snippet.id)
			.scrollContentBackground(.hidden)
			.frame(minHeight: 80)
			.focused($isNoteFocused)
			.onChange(of: snippet.note, initial: false) { _, newValue in
				guard !snippet.isTrashed else { return }
				if isNoteFocused {
					if newValue != previousNote {
						previousNote = newValue
						noteDirty = true
					}
				} else {
					previousNote = newValue
				}
			}
			.onChange(of: isNoteFocused) { _, focused in
				if focused {
					noteOriginalValue = snippet.note
				} else if noteDirty, !snippet.isTrashed {
					finalizeNoteEdit()
				}
			}
			.disabled(snippet.isTrashed)
			.padding(6)
			.background(.ultraThinMaterial)
			.clipShape(RoundedRectangle(cornerRadius: 15))
	}

	// MARK: - Toolbar Content

	private var toolbarContent: some ToolbarContent {
		Group {
			if !snippet.isTrashed {
				ToolbarItem(placement: .confirmationAction) {
					Group {
						switch snippet.type {
						case .path:
							AnyView(
								Button {
									if Device.isMac() {
										openInFinder(snippet.content)
									} else {
										unableToActionTitle = "Cannot Open Path"
										unableToActionMessage = "You need to use a Mac to open file paths."
										showUnableToActionAlert = true
									}

								} label: {
									if Device.isMac() {
										Label("Open Path", systemImage: "finder")
									} else {
										Label("Can't Open Path", systemImage: "exclamationmark.triangle")
											.foregroundStyle(.yellow)
									}
								}
							)

						case .link:
							AnyView(
								Button {
									if !openURL(snippet.content) {
										unableToActionTitle = "Invalid URL"
										unableToActionMessage = "You need to use a valid URL."
										showUnableToActionAlert = true
									}

								} label: {
									Label("Open URL", systemImage: "link")
								}
							)

						case .plainText:
							AnyView(EmptyView())

						case .code:
							AnyView(
								Menu {
									Picker(selection: $snippet.language) {
										ForEach(CodeEditor.availableLanguages) { language in
											Text("\(language.rawValue.capitalized)")
												.fontDesign(.monospaced)
												.tag(language)
										}
									} label: {}
										.pickerStyle(.inline)
								} label: {
									Label("Language", systemImage: "paintpalette")
								}
							)

						case .command:
							AnyView(
								Button {
									if Device.isMac() {
										showCommandSheet = true
									} else {
										unableToActionTitle = "Cannot Run Command"
										unableToActionMessage = "You need to use a Mac to run commands."
										showUnableToActionAlert = true
									}

								} label: {
									if Device.isMac() {
										Label("Run Command", systemImage: "terminal")
									} else {
										Label("Can't Run Command", systemImage: "exclamationmark.triangle")
											.foregroundStyle(.yellow)
									}
								}
							)

						case .secrets:
							AnyView(EmptyView())
						}
					}
					.tint(Device.isMac() ? .accent : .red)
				}
			}

			ToolbarSpacer()

			ToolbarItem(placement: .primaryAction) {
				Button {
					copyToClipboard(snippet.content)
				} label: {
					Label("Copy", systemImage: "document.on.document")
				}
			}
			ToolbarSpacer()

			if snippet.isTrashed {
				ToolbarItem(placement: .primaryAction) {
					Button {
						restoreSnippet()
					} label: {
						Label("Restore", systemImage: "arrow.uturn.backward")
					}
					.disabled(!snippet.isTrashed)
				}
			} else {
				ToolbarItem(placement: .destructiveAction) {
					Button(role: .destructive) {
						showingDeleteConfirmation = true
					} label: {
						Label("Delete", systemImage: "trash")
							.foregroundStyle(.red)
					}
					#if os(macOS)
					.keyboardShortcut(.delete, modifiers: [])
					#endif
				}
			}
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
		let oldTitle = snippet.title
		guard trimmed != oldTitle else { return }
		snippet.title = trimmed
		finalizeChange(
			actionName: "Rename Snippet",
			applyUndo: { target in target.title = oldTitle },
			applyRedo: { target in target.title = trimmed }
		)
	}

	private func commitTypeChange(_ newValue: SnippetType) {
		guard !snippet.isTrashed else {
			typeSelection = snippet.type
			return
		}
		let oldValue = snippet.type
		guard oldValue != newValue else { return }
		snippet.type = newValue
		finalizeChange(
			actionName: "Change Snippet Type",
			applyUndo: { target in target.type = oldValue },
			applyRedo: { target in target.type = newValue }
		)
	}

	private func finalizeChange(
		actionName: String,
		undoActionName: String? = nil,
		oldUpdatedAt: Date? = nil,
		applyUndo: @escaping (Snippet) -> Void,
		applyRedo: @escaping (Snippet) -> Void
	) {
		let context = modelContext
		let previousTimestamp = oldUpdatedAt ?? snippet.updatedAt
		snippet.updatedAt = .now

		let newTimestamp = snippet.updatedAt
		try? context.save()

		guard let undoManager else { return }
		let undoLabel = undoActionName ?? actionName
		undoManager.registerUndo(withTarget: snippet) { target in
			applyUndo(target)
			target.updatedAt = previousTimestamp
			try? context.save()
			undoManager.registerUndo(withTarget: target) { redoTarget in
				applyRedo(redoTarget)
				redoTarget.updatedAt = newTimestamp
				try? context.save()
			}
			undoManager.setActionName(actionName)
		}
		undoManager.setActionName(undoLabel)
	}

	private func finalizeContentEdit() {
		defer {
			contentDirty = false
			contentOriginalValue = snippet.content
			previousContent = snippet.content
		}
		guard !snippet.isTrashed else { return }
		let oldValue = contentOriginalValue
		let newValue = snippet.content
		guard oldValue != newValue else { return }
		finalizeChange(
			actionName: "Edit Content",
			applyUndo: { target in target.content = oldValue },
			applyRedo: { target in target.content = newValue }
		)
	}

	private func finalizeNoteEdit() {
		defer {
			noteDirty = false
			noteOriginalValue = snippet.note
			previousNote = snippet.note
		}
		guard !snippet.isTrashed else { return }
		let oldValue = noteOriginalValue
		let newValue = snippet.note
		guard oldValue != newValue else { return }
		finalizeChange(
			actionName: "Edit Note",
			applyUndo: { target in target.note = oldValue },
			applyRedo: { target in target.note = newValue }
		)
	}

	private func applyTagChange(actionName: String, from oldTags: [String], to newTags: [String]) {
		guard !snippet.isTrashed else { return }
		guard oldTags != newTags else { return }
		snippet.tags = newTags

		finalizeChange(
			actionName: actionName,
			applyUndo: { target in target.tags = oldTags },
			applyRedo: { target in target.tags = newTags }
		)
	}

	private func moveSnippetToTrash() {
		showingDeleteConfirmation = false
		guard !snippet.isTrashed else { return }
		let previousFolder = snippet.folder
		let previousTrashID = snippet.trashedFolderID
		let trashID = previousFolder?.id ?? previousTrashID
		snippet.folder = nil
		snippet.trashedFolderID = trashID
		snippet.isTrashed = true
		finalizeChange(
			actionName: "Move to Recycle Bin",
			undoActionName: "Restore Snippet",
			applyUndo: { target in
				target.isTrashed = false
				target.trashedFolderID = nil
				target.folder = previousFolder
			},
			applyRedo: { target in
				target.folder = nil
				target.trashedFolderID = trashID
				target.isTrashed = true
			}
		)
	}

	private func restoreSnippet() {
		guard snippet.isTrashed else { return }
		let previousTrashID = snippet.trashedFolderID
		let restoredFolder = previousTrashID.flatMap { folder(with: $0) }
		let trashID = previousTrashID ?? restoredFolder?.id
		snippet.folder = restoredFolder
		snippet.isTrashed = false
		snippet.trashedFolderID = nil
		finalizeChange(
			actionName: "Restore Snippet",
			undoActionName: "Move to Recycle Bin",
			applyUndo: { target in
				target.isTrashed = true
				target.folder = nil
				target.trashedFolderID = trashID
			},
			applyRedo: { target in
				target.folder = restoredFolder
				target.isTrashed = false
				target.trashedFolderID = nil
			}
		)
	}

	private func folder(with id: UUID) -> Folder? {
		let descriptor = FetchDescriptor<Folder>(predicate: #Predicate { $0.id == id })
		return try? modelContext.fetch(descriptor).first
	}

	private func triggerTagAction(_ tag: String) {
		tagForAction = tag
		renameWorkingText = tag
		showingTagAlert = true
	}

	private func clearTagAlert() {
		tagForAction = nil
		renameWorkingText = ""
		showingTagAlert = false
	}

	private func commitRename() {
		let trimmed = renameWorkingText.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !trimmed.isEmpty else { clearTagAlert(); return }
		guard !snippet.isTrashed else { clearTagAlert(); return }
		let oldTags = snippet.tags
		var newTags = snippet.tags
		if let original = tagForAction {
			guard trimmed != original, !oldTags.contains(trimmed) else { clearTagAlert(); return }
			guard let idx = newTags.firstIndex(of: original) else { clearTagAlert(); return }
			newTags[idx] = trimmed
			applyTagChange(actionName: "Rename Tag", from: oldTags, to: newTags)
		} else {
			guard !oldTags.contains(trimmed) else { clearTagAlert(); return }
			newTags.append(trimmed)
			applyTagChange(actionName: "Add Tag", from: oldTags, to: newTags)
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
		let oldTags = snippet.tags
		var newTags = snippet.tags
		newTags.remove(at: idx)
		applyTagChange(actionName: "Remove Tag", from: oldTags, to: newTags)
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

private struct CommandRunnerSheet: View {
	@Environment(\.dismiss) private var dismiss
	let snippet: Snippet

	@State private var commandOutput = ""
	@State private var commandIsRunning = true
	@State private var commandSucceeded = false

	var body: some View {
		NavigationStack {
			ScrollView {
				Text(commandOutput)
					.font(.system(.body, design: .monospaced))
					.textSelection(.enabled)
			}
			.navigationTitle(snippet.content)
			.toolbar {
				ToolbarItem(placement: .confirmationAction) {
					Button {
						dismiss()
					} label: {
						if commandIsRunning {
							ProgressView()
								.progressViewStyle(.linear)
								.frame(width: 50, height: 15)
						} else if commandSucceeded {
							Image(systemName: "checkmark")
								.frame(height: 15)
						} else {
							Image(systemName: "xmark")
								.frame(height: 15)
						}
					}
					.buttonStyle(.glassProminent)
					.controlSize(.extraLarge)
					.buttonBorderShape(.roundedRectangle)
					.tint(commandIsRunning ? .gray : commandSucceeded ? .green : .red)
					.keyboardShortcut(.escape)
				}
			}
		}
		.interactiveDismissDisabled()
		.presentationDetents([.large])
		.presentationDragIndicator(.hidden)
		.onAppear { startCommandExecution() }
	}

	private func startCommandExecution() {
		commandOutput = ""
		commandIsRunning = true
		commandSucceeded = false

		#if os(macOS)
			runSwiftShell(
				commands: snippet.content
					.split(separator: "\n")
					.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
					.filter { !$0.isEmpty }
			) { outputLine, isRunning, success in
				commandOutput.append(outputLine + "\n")
				if commandOutput.count > 5000 {
					commandOutput.removeFirst(commandOutput.count - 5000)
				}
				commandIsRunning = isRunning
				if let result = success {
					commandSucceeded = result
				}
			}
		#else
			commandOutput = "Command execution is supported only on macOS."
			commandIsRunning = false
			commandSucceeded = false
		#endif
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
