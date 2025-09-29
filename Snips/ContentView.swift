//
//  ContentView.swift
//  Snips
//
//  Created by Adon Omeri on 9/9/2025.
//

import SwiftData
import SwiftUI

enum SidebarItem: Hashable {
	case all
	case section(SnippetType)
	case folder(Folder)
}

struct ContentView: View {
	@Environment(\.colorScheme) private var colorScheme
	@Environment(\.modelContext) private var modelContext

	@State private var selection: SidebarItem?
	@State private var selectedSnippetID: UUID?
	@State private var showAddFolderAlert = false
	@State private var newFolderName: String = ""
	@State private var editingSnippetID: UUID? = nil
	@State private var editingText: String = ""
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
			return allSnippets
		case let .section(type):
			return allSnippets.filter { $0.type == type }
		case let .folder(folder):
			return folder.snippets
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
		case nil:
			return ""
		}
	}

	var selectedSnippet: Snippet? {
		guard let id = selectedSnippetID else { return nil }
		return allSnippets.first { $0.id == id }
	}

	@State private var sortOption: SortOption = .dateUpdatedDescending

	let items = [SnippetType.path, .link, .code, .plainText, .command]

	var body: some View {
		NavigationSplitView {
			let sidebarItems: [SidebarItem] = [.all] + items.map { SidebarItem.section($0) }

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
							Text(folder.snippets.count.description)
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
							Text("Select a section or folder.")
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
							HStack {
								if editingSnippetID == snippet.id {
									TextField("", text: $editingText)
										.textFieldStyle(.roundedBorder)
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
						}
						.listStyle(.inset)
						.scrollContentBackground(.hidden)
						.animation(
							.interactiveSpring(response: 0.35, dampingFraction: 0.85),
							value: sortedSnippets.map(\.id)
						)
						.id(contentListID)
					}
				}
			}
			.navigationTitle(Text(contentColumnTitle))
			.toolbar {
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
		case nil:
			return "none"
		}
	}

	private func snippetCount(for item: SidebarItem) -> Int {
		switch item {
		case .all:
			return allSnippets.count
		case let .section(type):
			return allSnippets.reduce(0) { $1.type == type ? $0 + 1 : $0 }
		case let .folder(folder):
			return folder.snippets.count
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
					.foregroundStyle(.black)
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
			return .accentColor
		case let .section(type):
			return type.color
		case .folder:
			return Color.gray.opacity(0.35)
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
						.foregroundStyle(.black)
						.fontWeight(.bold)
						.imageScale(.medium)
					Text("All")
						.font(.title3)
				}
				.padding(.leading, 10)
				Spacer()
			}
			.frame(maxWidth: .infinity, maxHeight: .infinity)

		case let .section(type):
			HStack {
				VStack(alignment: .leading) {
					Image(systemName: type.symbol)
						.foregroundStyle(.black)
						.fontWeight(.bold)
						.imageScale(.medium)
					Text(type.title)
						.font(.title3)
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
		}
	}
}

private extension ContentView {
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
		guard let snippet = allSnippets.first(where: { $0.id == snippetID }) else { return }
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
