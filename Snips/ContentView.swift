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

	let items = [SnippetType.path, .link, .code, .plainText, .command]

	var body: some View {
		NavigationSplitView {
			let sidebarItems: [SidebarItem] = [.all] + items.map { SidebarItem.section($0) }

			List(selection: $selection) {
				Section {
					LazyVGrid(columns: [
						GridItem(.flexible()),
						GridItem(.flexible()),
					], spacing: 5) {
						ForEach(sidebarItems, id: \.self) { item in
							gridItemView(for: item)
						}
					}
				}
				Section("Folders") {
					ForEach(folders, id: \.id) { folder in
						Text(folder.name)
							.tag(SidebarItem.folder(folder))
					}
				}
			}
			.toolbar {
				Button("Add Random Snippet") {
					let folder: Folder
					if let existing = folders.randomElement() {
						folder = existing
					} else {
						folder = Folder(
							id: UUID(),
							name: "Debug Folder",
							orderIndex: 0,
							snippets: []
						)
						modelContext.insert(folder)
					}
					let types: [SnippetType] = [.path, .link, .plainText, .code]
					let type = types.randomElement()!

					let content: String
					switch type {
					case .path:
						content = "/Users/Example/Path\(Int.random(in: 1 ... 100))"
					case .link:
						content = "https://example.com/\(Int.random(in: 1 ... 100))"
					case .plainText:
						content = "Random note \(Int.random(in: 1 ... 100))"
					case .code, .command:
						content = "print(\"Hello \(Int.random(in: 1 ... 100))\")"
					}

					let snippet = Snippet(
						id: UUID(),
						title: "\(type.rawValue.capitalized) Snippet \(Int.random(in: 1 ... 1000))",
						type: type,
						tags: [],
						updatedAt: Date.now,
						folder: folder,
						content: content,
						note: ""
					)
					modelContext.insert(snippet)
					try? modelContext.save()
				}
			}
			.navigationSplitViewColumnWidth(min: 350, ideal: 400, max: 600)
		} content: {
			Group {
				if selectedSnippets.isEmpty {
					List { Text("Select a snippet or folder") }
						.listStyle(.sidebar)
						.scrollDisabled(true)
						.transition(.blurReplace)
				} else {
					List(selectedSnippets, selection: $selectedSnippet) { snippet in
						Text(snippet.title)
							.tag(snippet)
					}
					.listStyle(.sidebar)
					.transition(.blurReplace)
				}
			}
			.toolbar {
				Button {} label: {
					Label("Sort", systemImage: "arrow.up.arrow.down")
				}
			}
			.animation(.easeInOut(duration: 0.3), value: selectedSnippets.isEmpty)
			.navigationSplitViewColumnWidth(min: 350, ideal: 400, max: 600)
		} detail: {
			if let selectedSnippet {
				SnippetDetailView(snippet: selectedSnippet)
			} else {
				List { Text("Select a snippet") }
					.listStyle(.sidebar)
					.scrollDisabled(true)
			}
		}
		.onAppear {
			selection = .all
			selectedSnippet = allSnippets.first
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
					.padding(6)
					.font(.caption2.monospacedDigit())
					.foregroundStyle(.black)
					.padding(6)
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
