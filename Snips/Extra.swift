//
//  Extra.swift
//  Snips
//
//  Created by Adon Omeri on 15/9/2025.
//

import SwiftUI
#if os(macOS)
	import AppKit
#else
	import UIKit
#endif

func copyToClipboard(_ string: String) {
	#if os(macOS)
		let pasteboard = NSPasteboard.general
		pasteboard.clearContents()
		pasteboard.setString(string, forType: .string)
	#else
		UIPasteboard.general.string = string
	#endif
}

func openInFinder(_ string: String) {
	#if os(macOS)
		let fileURL = URL(fileURLWithPath: string)
		NSWorkspace.shared.activateFileViewerSelecting([fileURL])
	#endif
}

func openURL(_ urlString: String) -> Bool {
	guard let url = URL(string: "https://" + urlString) else { return false }

	#if os(macOS)
		NSWorkspace.shared.open(url)
		return true
	#else
		if UIApplication.shared.canOpenURL(url) {
			UIApplication.shared.open(url, options: [:], completionHandler: nil)
			return true
		}
		return false
	#endif
}

extension View {
	@ViewBuilder
	func conditional<Content: View>(_ condition: Bool, _ transform: (Self) -> Content) -> some View {
		if condition {
			transform(self)
		} else {
			self
		}
	}
}

class Device {
	static func isPhone() -> Bool {
		#if os(iOS)
			return UIDevice.current.userInterfaceIdiom == .phone
		#else
			return false
		#endif
	}

	static func isPad() -> Bool {
		#if os(iOS)
			return UIDevice.current.userInterfaceIdiom == .pad
		#else
			return false
		#endif
	}

	static func isMac() -> Bool {
		#if os(macOS)
			return true
		#else
			return false
		#endif
	}
}
