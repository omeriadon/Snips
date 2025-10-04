//
//  Extra.swift
//  Snips
//
//  Created by Adon Omeri on 15/9/2025.
//

import SwiftUI
#if os(iOS)
	import UIKit
#endif

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
}

struct GoodStyle: TextFieldStyle {
	func _body(configuration: TextField<Self._Label>) -> some View {
		configuration
			.padding(3)
			.background(.clear)
			.clipShape(RoundedRectangle(cornerRadius: 5))
	}
}
