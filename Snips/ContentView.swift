//
//  ContentView.swift
//  Snips
//
//  Created by Adon Omeri on 9/9/2025.
//

import SwiftData
import SwiftUI
#if os(macOS)
	import AppKit
#elseif os(iOS)
	import UIKit
#endif

enum SidebarItem: Hashable {
	case all
	case section(SnippetType)
	case folder(Folder)
	case trash
}

struct ContentView: View {
	@Environment(\.colorScheme) private var colorScheme
	@Environment(\.modelContext) private var modelContext
	@Environment(\.undoManager) private var undoManager

	@State private var selection: SidebarItem? = .all
	@State private var selectedSnippetID: UUID?
	@State private var showAddFolderAlert = false
	@State private var newFolderName: String = ""
	@State private var editingSnippetID: UUID? = nil
	@State private var editingText: String = ""
	@State private var showDeleteConfirmation = false
	@State private var snippetToDelete: Snippet?
	@State private var newSnippetDraft: Snippet?
	@FocusState private var isTextFieldFocused: Bool

	@Query(sort: [
		SortDescriptor(\Folder.orderIndex, order: .forward),
		SortDescriptor(\Folder.name, order: .forward),
	]) var folders: [Folder]
	@Query var allSnippets: [Snippet]

	var selectedSnippets: [Snippet] {
		guard let selection else { return [] }
		switch selection {
		case .all:
			return allSnippets.filter { !$0.isTrashed }
		case let .section(type):
			return allSnippets.filter { $0.type == type && !$0.isTrashed }
		case let .folder(folder):
			return folder.snippets.filter { !$0.isTrashed }
		case .trash:
			return allSnippets.filter { $0.isTrashed }
		}
	}

	var sortedSnippets: [Snippet] {
		let base = uniqueByID(selectedSnippets)
		switch sortOption {
		case .type:
			return base.sorted { $0.type.title < $1.type.title }
		case .typeDescending:
			return base.sorted { $0.type.title > $1.type.title }
		case .title:
			return base.sorted { $0.title < $1.title }
		case .titleDescending:
			return base.sorted { $0.title > $1.title }
		case .dateUpdated:
			return base.sorted { $0.updatedAt < $1.updatedAt }
		case .dateUpdatedDescending:
			return base.sorted { $0.updatedAt > $1.updatedAt }
		}
	}

	private func uniqueByID(_ items: [Snippet]) -> [Snippet] {
		var seen = Set<UUID>()
		var result: [Snippet] = []
		result.reserveCapacity(items.count)
		for s in items {
			if seen.insert(s.id).inserted { result.append(s) }
		}
		return result
	}

	var contentColumnTitle: String {
		switch selection {
		case .all:
			return "All"
		case let .section(snippetType):
			return snippetType.title
		case let .folder(folder):
			return folder.name
		case .trash:
			return "Recycle Bin"
		case nil:
			return ""
		}
	}

	var emptyStateMessage: String {
		guard let selection else { return "Select a section or folder." }
		switch selection {
		case .all:
			return "No snippets yet. Create one to get started."
		case .trash:
			return "Recycle Bin is empty."
		case .section, .folder:
			return "Nothing to show here yet."
		}
	}

	var selectedSnippet: Snippet? {
		guard let id = selectedSnippetID else { return nil }
		guard let snippet = allSnippets.first(where: { $0.id == id }) else { return nil }
		if snippet.isTrashed, selection != .trash { return nil }
		return snippet
	}

	@State private var sortOption: SortOption = .dateUpdatedDescending

	let items = [SnippetType.path, .link, .code, .plainText, .command, .secrets]

	var body: some View {
		// MARK: - Sidebar

		NavigationSplitView {
			let sidebarItems: [SidebarItem] = [.all] + items.map { SidebarItem.section($0) } + [.trash]

			List(selection: $selection) {
				LazyVGrid(columns: [
					GridItem(.flexible()),
					GridItem(.flexible()),
				], spacing: 5) {
					ForEach(Array(sidebarItems.enumerated()), id: \.element) { _, item in
						gridItemView(for: item)
					}
				}
				.listRowBackground(Color.clear)
				.conditional(Device.isPad()) {
					$0.padding(.horizontal, -15)
				}
				Section {
					ForEach(folders, id: \.id) { folder in
						HStack {
							Text(folder.name)
							Spacer()
							Text(folder.snippets.filter { !$0.isTrashed }.count.description)
								.foregroundStyle(.secondary)
						}
						.tag(SidebarItem.folder(folder))
						.dropDestination(for: SnippetTransfer.self) { items, _ in
							var changedSelection: UUID? = nil
							for transfer in items {
								let existing = allSnippets.first(where: { $0.id == transfer.id })
								let new = cloneSnippet(from: transfer, existing: existing) { clone in
									clone.folder = folder
								}
								if existing != nil { modelContext.delete(existing!) }
								if selectedSnippetID == existing?.id { changedSelection = new.id }
							}
							if let newSel = changedSelection { selectedSnippetID = newSel }
							try? modelContext.save()
							return true
						}
					}
				} header: {
					HStack {
						Text("Folders")
						Spacer()
						Button {
							newFolderName = ""
							showAddFolderAlert = true
						} label: {
							Image(systemName: "plus")
						}
						.buttonStyle(.glass)
						.controlSize(.small)
					}
					.padding(.bottom, 5)
					#if os(macOS)
						.padding(.trailing, 10)
					#endif
						.conditional(Device.isPad()) {
							$0
								.padding(.trailing, -20)
								.padding(.leading, -10)
						}
						.conditional(Device.isPhone()) {
							$0.padding(.trailing, -10)
						}
				}
			}
			.navigationTitle(Text("Snips"))
			.navigationSplitViewColumnWidth(min: 270, ideal: 300, max: 600)

			// MARK: - Content
		} content: {
			Group {
				if selectedSnippets.isEmpty {
					ZStack {
						if colorScheme == .dark {
							List {}
								.listStyle(.sidebar)
						} else {
							List {}
								.listStyle(.plain)
						}
						List {
							Text(emptyStateMessage)
						}
						.listStyle(.inset)
						.scrollContentBackground(.hidden)
						.scrollDisabled(true)
					}
				} else {
					ZStack {
						if colorScheme == .dark {
							List {}
								.listStyle(.sidebar)
						} else {
							List {}
								.listStyle(.plain)
						}
						List(
							sortedSnippets,
							selection: $selectedSnippetID
						) { snippet in
							HStack(spacing: 0) {
								if editingSnippetID == snippet.id {
									TextField("", text: $editingText)
										.textFieldStyle(GoodStyle())
										.scrollContentBackground(.hidden)
										.background(Color.clear)
										.focused($isTextFieldFocused)
										.onSubmit {
											saveRename()
										}
										.onExitCommand {
											cancelRename()
										}
								} else {
									Text(snippet.title)
								}
								Spacer(minLength: 10)
								if editingSnippetID == nil || editingSnippetID != snippet.id {
									Text(snippet.content)
										.foregroundStyle(.secondary)
										.lineLimit(1)
										.truncationMode(.tail) // useful for single-line
										.mask(
											LinearGradient(
												gradient: Gradient(stops: [
													.init(color: .black, location: 0.75), // fully opaque until 70% in
													.init(color: .clear, location: 1.0), // fades to transparent at the very end
												]),
												startPoint: .leading,
												endPoint: .trailing
											)
										)
								}

								Spacer()
								if case .section = selection {} else {
									Spacer()
									Image(systemName: snippet.type.symbol)
										.imageScale(.small)
										.foregroundStyle(.black)
										.padding(4)
										.glassEffect(
											.clear.tint(snippet.type.color),
											in: .capsule
										)
								}
							}
							.frame(minHeight: 25)
							.tag(snippet.id)
							.draggable(snippet.transferable)
							.listRowSeparator(.hidden)
							.contextMenu {
								if snippet.isTrashed {
									Button {
										restoreSnippet(snippet)
									} label: {
										Label("Restore", systemImage: "arrow.uturn.backward")
									}

									Divider()

									Button(role: .destructive) {
										deletePermanently(snippet)
									} label: {
										Label("Delete Permanently", systemImage: "trash.fill")
											.foregroundStyle(.red)
									}
								} else {
									Button {
										startRename(for: snippet.id)
									} label: {
										Label("Rename", systemImage: "pencil")
									}

									Button {
										duplicateSnippet(snippet)
									} label: {
										Label("Duplicate", systemImage: "doc.on.doc")
									}

									Button {
										copyToClipboard(snippet.content)
									} label: {
										Label("Copy Content", systemImage: "doc.on.clipboard")
									}

									Menu {
										ForEach(SnippetType.allCases, id: \.self) { type in
											Button {
												changeSnippetType(snippet, to: type)
											} label: {
												Label(type.title, systemImage: type.symbol)
											}
										}
									} label: {
										Label("Change Type", systemImage: "arrow.triangle.2.circlepath")
									}

									if snippet.folder != nil {
										Button {
											removeFromFolder(snippet)
										} label: {
											Label("Remove from Folder", systemImage: "folder.badge.minus")
										}
									}

									Divider()

									Button(role: .destructive) {
										snippetToDelete = snippet
										showDeleteConfirmation = true
									} label: {
										Label("Move to Recycle Bin", systemImage: "trash")
											.foregroundStyle(.red)
									}
								}
							}
							.swipeActions(edge: .trailing, allowsFullSwipe: false) {
								if snippet.isTrashed {
									Button {
										restoreSnippet(snippet)
									} label: {
										Label("Restore", systemImage: "arrow.uturn.backward")
									}
									.tint(.green)

									Button(role: .destructive) {
										deletePermanently(snippet)
									} label: {
										Label("Delete", systemImage: "trash")
									}
									.tint(.red)
								} else {
									Button(role: .destructive) {
										snippetToDelete = snippet
										showDeleteConfirmation = true
									} label: {
										Label("Delete", systemImage: "trash")
									}
									.tint(.red)
								}
							}
						}
						.listStyle(.inset)
						.scrollContentBackground(.hidden)
						.animation(
							.interactiveSpring(response: 0.35, dampingFraction: 0.85),
							value: allSnippets.map(\.id)
						)
						.id(contentListID)
					}
				}
			}
			.navigationTitle(Text(contentColumnTitle))
			.toolbar {
				ToolbarItem(placement: .principal) {
					Button {
						startNewSnippet()
					} label: {
						Label("New Snippet", systemImage: "plus")
					}
				}
				ToolbarSpacer()
				ToolbarItem(placement: .primaryAction) {
					Picker(selection: $sortOption) {
						Section {
							Label("Type", systemImage: "rectangle.on.rectangle.angled")
								.tag(isAscending ? SortOption.type : SortOption.typeDescending)
							Label("Title", systemImage: "textformat")
								.tag(isAscending ? SortOption.title : SortOption.titleDescending)
							Label("Updated", systemImage: "calendar")
								.tag(isAscending ? SortOption.dateUpdated : SortOption.dateUpdatedDescending)
						}

						Divider()

						Section {
							Label("Ascending", systemImage: "arrow.up")
								.tag(tagForOrder(true))
							Label("Descending", systemImage: "arrow.down")
								.tag(tagForOrder(false))
						}
					} label: {
						Label("Sort", systemImage: "arrow.up.arrow.down")
					}
				}
			}
			.navigationSplitViewColumnWidth(min: 250, ideal: 300, max: 600)
			.onChange(of: sortedSnippets.map(\.id)) { _, ids in
				if let sel = selectedSnippetID, !ids.contains(sel) {
					selectedSnippetID = nil
				}
			}

			// MARK: - Detail
		} detail: {
			Group {
				if let selectedSnippet {
					SnippetDetailView(snippet: selectedSnippet)
				} else {
					ZStack {
						if colorScheme == .dark {
							List {}
								.listStyle(.sidebar)
						} else {
							List {}
								.listStyle(.plain)
						}

						List {
							Text("Select a snippet.")
						}
						.listStyle(.inset)
						.scrollContentBackground(.hidden)
						.scrollDisabled(true)
					}
					.toolbar {
						ToolbarItem(placement: .primaryAction) {
							Button { /* to keep window design  */ } label: { Label("bookmark", systemImage: "bookmark") }
								.disabled(true)
						}
					}
				}
			}
		}
		.alert("New Folder", isPresented: $showAddFolderAlert) {
			TextField("Name", text: $newFolderName)
			Button("Create", role: .confirm) { createFolder() }
			Button("Cancel", role: .cancel) { newFolderName = "" }
		} message: {
			Text("Enter a folder name.")
		}
		.alert("Move to Recycle Bin", isPresented: $showDeleteConfirmation) {
			Button("Move", role: .destructive) {
				if let snippet = snippetToDelete {
					deleteSnippet(snippet)
				}
			}
			Button("Cancel", role: .cancel) {
				snippetToDelete = nil
			}
		} message: {
			if let snippet = snippetToDelete {
				Text("Move '\(snippet.title)' to the Recycle Bin? You can restore it later.")
			}
		}
		.onChange(of: selection) {
			selectedSnippetID = nil
			cancelRename()
		}
		.onChange(of: selectedSnippetID) { _, _ in
			cancelRename()
		}
		.onKeyPress(.return) {
			if editingSnippetID == nil, let selectedSnippetID = selectedSnippetID {
				startRename(for: selectedSnippetID)
			}
			return .ignored
		}
		.sheet(item: $newSnippetDraft) { snippet in
			NavigationStack {
				SnippetDetailView(snippet: snippet)
					.toolbar {
						ToolbarItem(placement: .cancellationAction) {
							Button(role: .cancel) {
								cancelNewSnippet(snippet)
							} label: {
								Label("Cancel", systemImage: "xmark")
							}
						}
						ToolbarItem(placement: .confirmationAction) {
							Button(role: .confirm) {
								completeNewSnippet(snippet)
							} label: {
								Label("Add", systemImage: "checkmark")
							}
						}
					}
			}
			.frame(minWidth: 350, minHeight: 500)
			.interactiveDismissDisabled(true)
		}
	}

	// MARK: - Sort helpers

	private enum SortField { case type, title, dateUpdated }

	private var currentSortField: SortField {
		switch sortOption {
		case .type, .typeDescending:
			return .type
		case .title, .titleDescending:
			return .title
		case .dateUpdated, .dateUpdatedDescending:
			return .dateUpdated
		}
	}

	private var isAscending: Bool {
		switch sortOption {
		case .type, .title, .dateUpdated:
			return true
		case .typeDescending, .titleDescending, .dateUpdatedDescending:
			return false
		}
	}

	private func tagForOrder(_ ascending: Bool) -> SortOption {
		switch (currentSortField, ascending) {
		case (.type, true): return .type
		case (.type, false): return .typeDescending
		case (.title, true): return .title
		case (.title, false): return .titleDescending
		case (.dateUpdated, true): return .dateUpdated
		case (.dateUpdated, false): return .dateUpdatedDescending
		}
	}

	private var contentListID: String {
		switch selection {
		case .all:
			return "all"
		case let .section(type):
			return "type-\(type.rawValue)"
		case let .folder(folder):
			return "folder-\(folder.id.uuidString)"
		case .trash:
			return "trash"
		case nil:
			return "none"
		}
	}

	private func snippetCount(for item: SidebarItem) -> Int {
		switch item {
		case .all:
			return allSnippets.filter { !$0.isTrashed }.count
		case let .section(type):
			return allSnippets.reduce(0) { $1.type == type && !$1.isTrashed ? $0 + 1 : $0 }
		case let .folder(folder):
			return folder.snippets.filter { !$0.isTrashed }.count
		case .trash:
			return allSnippets.filter { $0.isTrashed }.count
		}
	}

	@ViewBuilder
	private func gridItemView(for item: SidebarItem) -> some View {
		Button {
			selection = item
		} label: {
			ZStack(alignment: .topTrailing) {
				ConcentricRectangle(corners: .concentric, isUniform: true)
					.fill(gradient(for: item))
					.overlay(
						ConcentricRectangle(corners: .concentric, isUniform: true)
							.stroke(
								selection == item ? Color.primary : Color.clear,
								lineWidth: 2
							)
					)
					.compositingGroup()

				itemInnerContent(for: item)
					.font(.title2)
					.foregroundStyle(.black)
					.frame(height: 60)
					.frame(maxWidth: .infinity)

				Text("\(snippetCount(for: item))")
					.font(.caption2.monospacedDigit())
					.foregroundStyle(.white)
					.padding(10)
			}
			.animation(.easeInOut(duration: 0.2), value: selection == item)
			.contentShape(Rectangle())
			.containerShape(.rect(cornerRadius: 16))
		}
		.buttonStyle(.plain)
		.conditional({
			if case .section = item {
				return true
			} else {
				return false
			}
		}()) { view in
			view.dropDestination(for: SnippetTransfer.self) { items, _ in
				var changedSelection: UUID? = nil
				for transfer in items {
					let existing = allSnippets.first(where: { $0.id == transfer.id })
					let new = cloneSnippet(from: transfer, existing: existing) { clone in
						if case let .section(t) = item { clone.type = t }
					}
					if existing != nil { modelContext.delete(existing!) }
					if selectedSnippetID == existing?.id { changedSelection = new.id }
				}
				if let newSel = changedSelection { selectedSnippetID = newSel }
				try? modelContext.save()
				return true
			}
		}
	}

	private func baseColor(for item: SidebarItem) -> Color {
		switch item {
		case .all:
			return Color.accent
		case let .section(type):
			return type.color
		case .folder:
			return Color.gray.opacity(0.35)
		case .trash:
			return Color.gray.opacity(0.25)
		}
	}

	private func gradient(for item: SidebarItem) -> LinearGradient {
		let base = baseColor(for: item)
		let lighter = base.adjustBrightness(by: 0)
		let darker = base.adjustBrightness(by: -0.2)
		return LinearGradient(
			colors: [lighter, darker],
			startPoint: .topLeading,
			endPoint: .bottomTrailing
		)
	}

	@ViewBuilder
	private func itemInnerContent(for item: SidebarItem) -> some View {
		switch item {
		case .all:
			HStack {
				VStack(alignment: .leading) {
					Image(systemName: "square.grid.2x2")
						.foregroundStyle(.white)
						.fontWeight(.bold)
						.imageScale(.medium)
					Text("All")
						.font(.title3)
						.foregroundStyle(.white)
				}
				.padding(.leading, 10)
				Spacer()
			}
			.frame(maxWidth: .infinity, maxHeight: .infinity)

		case let .section(type):
			HStack {
				VStack(alignment: .leading) {
					Image(systemName: type.symbol)
						.foregroundStyle(.white)
						.fontWeight(.bold)
						.imageScale(.medium)
					Text(type.title)
						.font(.title3)
						.foregroundStyle(.white)
				}
				.padding(.leading, 10)
				Spacer()
			}
			.frame(maxWidth: .infinity, maxHeight: .infinity)

		case .folder:
			HStack {
				VStack(alignment: .leading) {
					Image(systemName: "folder")
						.foregroundStyle(.black)
						.fontWeight(.bold)
						.imageScale(.medium)
					Text("Folder")
						.font(.title3)
				}
				.padding(.leading, 10)
				Spacer()
			}
			.frame(maxWidth: .infinity, maxHeight: .infinity)

		case .trash:
			HStack {
				VStack(alignment: .leading) {
					Image(systemName: "trash")
						.foregroundStyle(.white)
						.fontWeight(.bold)
						.imageScale(.medium)
					Text("Recycle Bin")
						.foregroundStyle(.white)
						.font(.title3)
				}
				.padding(.leading, 10)
				Spacer()
			}
			.frame(maxWidth: .infinity, maxHeight: .infinity)
		}
	}
}

private extension ContentView {
	func startNewSnippet() {
		guard newSnippetDraft == nil else { return }
		let targetFolder = defaultFolderForNewSnippet()
		let targetType = defaultTypeForNewSnippet()
		let snippet = Snippet(
			id: UUID(),
			title: "New Snippet",
			type: targetType,
			tags: [],
			updatedAt: Date(),
			isTrashed: false,
			trashedFolderID: nil,
			folder: targetFolder,
			content: "",
			note: ""
		)
		modelContext.insert(snippet)
		try? modelContext.save()
		newSnippetDraft = snippet

		let targetSelection = selectionForNewSnippet(folder: targetFolder, type: targetType)
		if selection != targetSelection {
			selection = targetSelection
		}
	}

	func cancelNewSnippet(_ snippet: Snippet) {
		if selectedSnippetID == snippet.id {
			selectedSnippetID = nil
		}
		modelContext.delete(snippet)
		try? modelContext.save()
		newSnippetDraft = nil
	}

	func completeNewSnippet(_ snippet: Snippet) {
		snippet.updatedAt = Date()
		try? modelContext.save()
		newSnippetDraft = nil

		let targetSelection = selectionForCompletedSnippet(snippet)
		if selection != targetSelection {
			selection = targetSelection
			DispatchQueue.main.async {
				selectedSnippetID = snippet.id
			}
		} else {
			selectedSnippetID = snippet.id
		}
	}

	func defaultFolderForNewSnippet() -> Folder? {
		if case let .folder(folder) = selection {
			return folder
		}
		return nil
	}

	func defaultTypeForNewSnippet() -> SnippetType {
		if case let .section(type) = selection {
			return type
		}
		return .plainText
	}

	func selectionForNewSnippet(folder: Folder?, type: SnippetType) -> SidebarItem {
		if let folder {
			return .folder(folder)
		}
		switch selection {
		case .section:
			return .section(type)
		case .trash, nil:
			return .all
		case .all:
			return .all
		case .folder:
			return .all
		}
	}

	func selectionForCompletedSnippet(_ snippet: Snippet) -> SidebarItem {
		if let folder = snippet.folder {
			return .folder(folder)
		}
		return .section(snippet.type)
	}

	func createFolder() {
		let trimmed = newFolderName.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !trimmed.isEmpty else { return }
		guard !folders.contains(where: { $0.name.caseInsensitiveCompare(trimmed) == .orderedSame }) else { return }
		let nextOrder = (folders.map { $0.orderIndex }.max() ?? -1) + 1
		let folder = Folder(id: UUID(), name: trimmed, orderIndex: nextOrder, snippets: [])
		modelContext.insert(folder)
		try? modelContext.save()
		selection = .folder(folder)
		newFolderName = ""
	}

	@discardableResult
	func cloneSnippet(from transfer: SnippetTransfer, existing _: Snippet?, customize: (inout Snippet) -> Void = { _ in }) -> Snippet {
		var clone = Snippet(
			id: UUID(),
			title: transfer.title,
			type: transfer.type,
			tags: transfer.tags,
			updatedAt: Date(),
			folder: nil,
			content: transfer.content,
			note: transfer.note
		)
		customize(&clone)
		modelContext.insert(clone)
		return clone
	}

	func startRename(for snippetID: UUID) {
		guard let snippet = allSnippets.first(where: { $0.id == snippetID }), !snippet.isTrashed else { return }
		editingSnippetID = snippetID
		editingText = snippet.title
		isTextFieldFocused = true
	}

	func saveRename() {
		guard let editingID = editingSnippetID,
		      let snippet = allSnippets.first(where: { $0.id == editingID })
		else {
			cancelRename()
			return
		}

		let trimmed = editingText.trimmingCharacters(in: .whitespacesAndNewlines)
		if !trimmed.isEmpty {
			snippet.title = trimmed
			snippet.updatedAt = Date()
			try? modelContext.save()
		}

		cancelRename()
	}

	func cancelRename() {
		editingSnippetID = nil
		editingText = ""
		isTextFieldFocused = false
	}

	func duplicateSnippet(_ snippet: Snippet) {
		guard !snippet.isTrashed else { return }
		let duplicate = Snippet(
			id: UUID(),
			title: "\(snippet.title) Copy",
			type: snippet.type,
			tags: snippet.tags,
			updatedAt: Date(),
			folder: snippet.folder,
			content: snippet.content,
			note: snippet.note
		)
		modelContext.insert(duplicate)
		try? modelContext.save()
		selectedSnippetID = duplicate.id
	}

	func copyToClipboard(_ content: String) {
		#if os(macOS)
			NSPasteboard.general.clearContents()
			NSPasteboard.general.setString(content, forType: .string)
		#elseif os(iOS)
			UIPasteboard.general.string = content
		#endif
	}

	func removeFromFolder(_ snippet: Snippet) {
		guard !snippet.isTrashed else { return }
		snippet.folder = nil
		snippet.updatedAt = Date()
		try? modelContext.save()
	}

	func changeSnippetType(_ snippet: Snippet, to newType: SnippetType) {
		guard !snippet.isTrashed else { return }
		snippet.type = newType
		snippet.updatedAt = Date()
		try? modelContext.save()
	}

	func deleteSnippet(_ snippet: Snippet) {
		moveSnippetToTrash(snippet)
	}

	func moveSnippetToTrash(_ snippet: Snippet, registerUndo: Bool = true) {
		guard !snippet.isTrashed else { return }
		let previousFolderID = snippet.folder?.id ?? snippet.trashedFolderID
		snippet.trashedFolderID = previousFolderID
		snippet.folder = nil
		snippet.isTrashed = true
		snippet.updatedAt = Date()
		if selectedSnippetID == snippet.id {
			selectedSnippetID = nil
		}
		try? modelContext.save()
		snippetToDelete = nil

		if registerUndo, let undoManager {
			undoManager.registerUndo(withTarget: snippet) { target in
				restoreSnippet(target, registerUndo: true)
			}
			undoManager.setActionName("Restore Snippet")
		}
	}

	func restoreSnippet(_ snippet: Snippet, registerUndo: Bool = true) {
		guard snippet.isTrashed else { return }
		let folderID = snippet.trashedFolderID
		if let folderID,
		   let folder = folders.first(where: { $0.id == folderID })
		{
			snippet.folder = folder
		} else {
			snippet.folder = nil
		}
		snippet.isTrashed = false
		snippet.trashedFolderID = nil
		snippet.updatedAt = Date()
		if selection == .trash {
			selectedSnippetID = nil
		} else {
			selectedSnippetID = snippet.id
		}
		try? modelContext.save()

		if registerUndo, let undoManager {
			undoManager.registerUndo(withTarget: snippet) { target in
				moveSnippetToTrash(target, registerUndo: true)
			}
			undoManager.setActionName("Move to Recycle Bin")
		}
	}

	func deletePermanently(_ snippet: Snippet) {
		guard snippet.isTrashed else { return }
		let folderID = snippet.trashedFolderID ?? snippet.folder?.id
		let transfer = snippet.transferable

		if selectedSnippetID == snippet.id {
			selectedSnippetID = nil
		}
		modelContext.delete(snippet)
		try? modelContext.save()
		snippetToDelete = nil

		if let undoManager {
			undoManager.registerUndo(withTarget: modelContext) { context in
				let restored = Snippet(
					id: transfer.id,
					title: transfer.title,
					type: transfer.type,
					tags: transfer.tags,
					updatedAt: Date(),
					isTrashed: true,
					trashedFolderID: folderID,
					folder: nil,
					content: transfer.content,
					note: transfer.note
				)
				context.insert(restored)
				try? context.save()
			}
			undoManager.setActionName("Restore Snippet")
		}
	}
}

private extension Color {
	/// Adjust perceived brightness by modifying HSB brightness or RGB fallback
	func adjustBrightness(by delta: Double) -> Color {
		#if canImport(UIKit)
			let ui = UIColor(self)
			var h: CGFloat = 0
			var s: CGFloat = 0
			var b: CGFloat = 0
			var a: CGFloat = 0
			if ui.getHue(&h, saturation: &s, brightness: &b, alpha: &a) {
				let nb = max(0, min(1, b + CGFloat(delta)))
				return Color(hue: Double(h), saturation: Double(s), brightness: Double(nb), opacity: Double(a))
			}
			var r: CGFloat = 0
			var g: CGFloat = 0
			var bl: CGFloat = 0
			if ui.getRed(&r, green: &g, blue: &bl, alpha: &a) {
				let adj: (CGFloat) -> CGFloat = { c in
					let v = c + CGFloat(delta)
					return max(0, min(1, v))
				}
				return Color(red: Double(adj(r)), green: Double(adj(g)), blue: Double(adj(bl)), opacity: Double(a))
			}
			return self
		#elseif canImport(AppKit)
			let ns = NSColor(self)
			if let conv = ns.usingColorSpace(.deviceRGB) {
				var h: CGFloat = 0
				var s: CGFloat = 0
				var b: CGFloat = 0
				var a: CGFloat = 0
				conv.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
				let nb = max(0, min(1, b + CGFloat(delta)))
				return Color(hue: Double(h), saturation: Double(s), brightness: Double(nb), opacity: Double(a))
			}
			return self
		#else
			return self
		#endif
	}
}

#Preview {
	ContentView()
}

enum SortOption: CaseIterable, Hashable {
	case type
	case typeDescending
	case title
	case titleDescending
	case dateUpdated
	case dateUpdatedDescending

	var title: String {
		switch self {
		case .type:
			"Type"
		case .typeDescending:
			"Type Descending"
		case .title:
			"Title"
		case .titleDescending:
			"Title Descending"
		case .dateUpdated:
			"Updated"
		case .dateUpdatedDescending:
			"Updated Descending"
		}
	}

	var symbol: String {
		switch self {
		case .type:
			"rectangle.on.rectangle.angled"
		case .typeDescending:
			"arrow.up"
		case .title:
			"textformat"
		case .titleDescending:
			"arrow.up"
		case .dateUpdated:
			"calendar"
		case .dateUpdatedDescending:
			"arrow.up"
		}
	}
}
