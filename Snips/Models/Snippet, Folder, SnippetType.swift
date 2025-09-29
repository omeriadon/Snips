//
//  Snippet, Folder, SnippetType.swift
//  Snips
//
//  Created by Adon Omeri on 10/9/2025.
//

import Foundation
import SwiftData
import SwiftUI
internal import UniformTypeIdentifiers

enum SnippetType: String, Codable, CaseIterable {
	case path
	case link
	case plainText
	case code
	case command

	var title: String {
		switch self {
		case .path:
			"Paths"
		case .link:
			"Links"
		case .plainText:
			"Plain Text"
		case .code:
			"Code"
		case .command:
			"Commands"
		}
	}

	var symbol: String {
		switch self {
		case .path:
			"finder"
		case .link:
			"link"
		case .plainText:
			"text.quote"
		case .code:
			"ellipsis.curlybraces"
		case .command:
			"apple.terminal"
		}
	}

	var color: Color {
		switch self {
		case .path:
			.blue
		case .link:
			.green
		case .plainText:
			.orange
		case .code:
			.red
		case .command:
			.teal
		}
	}
}

@Model
class Folder {
	@Attribute(.unique) var id: UUID
	var name: String
	var orderIndex: Int
	@Relationship(deleteRule: .nullify, inverse: \Snippet.folder) var snippets: [Snippet]

	init(id: UUID, name: String, orderIndex: Int, snippets: [Snippet]) {
		self.id = id
		self.name = name
		self.orderIndex = orderIndex
		self.snippets = snippets
	}
}

@Model
class Snippet: Identifiable {
	@Attribute(.unique) var id: UUID
	var title: String

	var type: SnippetType
	var tags: [String]

	var updatedAt: Date

	@Relationship var folder: Folder?

	var content: String
	var note: String

	init(
		id: UUID,
		title: String,
		type: SnippetType,
		tags: [String],
		updatedAt: Date,
		folder: Folder? = nil,
		content: String,
		note: String
	) {
		self.id = id
		self.title = title
		self.type = type
		self.tags = tags
		self.updatedAt = updatedAt
		self.folder = folder
		self.content = content
		self.note = note
	}

	var transferable: SnippetTransfer {
		SnippetTransfer(
			id: id,
			title: title,
			type: type,
			tags: tags,
			updatedAt: updatedAt,
			content: content,
			note: note
		)
	}
}

struct SnippetTransfer: Transferable, Hashable, Codable {
	var id: UUID
	var title: String

	var type: SnippetType
	var tags: [String]

	var updatedAt: Date

	var content: String
	var note: String

	static var transferRepresentation: some TransferRepresentation {
		CodableRepresentation(for: SnippetTransfer.self, contentType: .data)
	}
}
