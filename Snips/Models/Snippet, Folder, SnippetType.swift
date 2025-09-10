//
//  Snippet, Folder, SnippetType.swift
//  Snips
//
//  Created by Adon Omeri on 10/9/2025.
//

import Foundation
import SwiftData

enum SnippetType: String, Codable {
	case finderPath
	case webLink
	case plainText
	case code
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
class Snippet {
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
}
