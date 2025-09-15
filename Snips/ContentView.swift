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
	@Environment(\.modelContext) private var modelContext

	@State private var selection: SidebarItem?
	@State private var selectedSnippet: Snippet?
	@State private var showAddFolderAlert = false
	@State private var newFolderName: String = ""

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
						Text(folder.name)
							.tag(SidebarItem.folder(folder))
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
		} content: {
			Group {
				if selectedSnippets.isEmpty {
					List {
						Text("Select a section or folder.")
							.listRowBackground(Color.clear)
					}
					.listStyle(.sidebar)
					.scrollDisabled(true)
				} else {
					List(selectedSnippets, selection: $selectedSnippet) { snippet in
						Text(snippet.title)
							.tag(snippet)
					}
					.listStyle(.sidebar)
				}
			}
			.navigationTitle(Text(contentColumnTitle))
			.toolbar {
				Button {} label: {
					Label("Sort", systemImage: "arrow.up.arrow.down")
				}
			}
			.navigationSplitViewColumnWidth(min: 250, ideal: 300, max: 600)
		} detail: {
			if let selectedSnippet {
				SnippetDetailView(snippet: selectedSnippet)
			} else {
				List {
					Text("Select a snippet.")
						.listRowBackground(Color.clear)
				}
				.listStyle(.sidebar)
				.scrollDisabled(true)
				.transition(.blurReplace)
			}
		}
		.alert("New Folder", isPresented: $showAddFolderAlert) {
			TextField("Name", text: $newFolderName)
			Button("Create", role: .confirm) { createFolder() }
			Button("Cancel", role: .cancel) { newFolderName = "" }
		} message: {
			Text("Enter a folder name.")
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
							.stroke(selection == item ? Color.white : Color.clear, lineWidth: 4)
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
		// Prevent duplicate names (optional simple check)
		guard !folders.contains(where: { $0.name.caseInsensitiveCompare(trimmed) == .orderedSame }) else { return }
		let nextOrder = (folders.map { $0.orderIndex }.max() ?? -1) + 1
		let folder = Folder(id: UUID(), name: trimmed, orderIndex: nextOrder, snippets: [])
		modelContext.insert(folder)
		try? modelContext.save()
		selection = .folder(folder)
		newFolderName = ""
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
