//
//  SwiftShell.swift
//  SwiftShell
//
//  Created by Adon Omeri on 8/10/2025.
//

import Foundation

#if canImport(SwiftShell)
internal import SwiftShell

public func runSwiftShell(
	commands: [String],
	update: @escaping (_ commandOutput: String, _ commandIsRunning: Bool, _ commandSucceeded: Bool?) -> Void
) {
	guard !commands.isEmpty else {
		DispatchQueue.main.async {
			update("No commands to run.", false, true)
		}
		return
	}

	let sendUpdate: (String, Bool, Bool?) -> Void = { message, running, success in
		DispatchQueue.main.async {
			update(message, running, success)
		}
	}

	DispatchQueue.global(qos: .userInitiated).async {
		var overallSuccess = true

		for rawLine in commands {
			let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
			guard !line.isEmpty else { continue }

			let parts = line.split(separator: " ").map(String.init)
			guard let rawExecutable = parts.first else { continue }
			let executable = rawExecutable.trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
			guard !executable.isEmpty else { continue }

			sendUpdate("$ \(line)", true, nil)

			let whichResult = run("/usr/bin/which", executable)
			guard whichResult.succeeded else {
				sendUpdate("Executable not found: \(executable)", true, false)
				overallSuccess = false
				continue
			}

			let result = run(bash: line)

			if !result.stdout.isEmpty {
				let stdoutLines = result.stdout.split(whereSeparator: \Character.isNewline)
				for stdoutLine in stdoutLines where !stdoutLine.isEmpty {
					sendUpdate(String(stdoutLine), true, nil)
				}
			}

			if !result.stderror.isEmpty {
				let stderrLines = result.stderror.split(whereSeparator: \Character.isNewline)
				for stderrLine in stderrLines where !stderrLine.isEmpty {
					sendUpdate("[stderr] \(stderrLine)", true, nil)
				}
			}

			if !result.succeeded {
				overallSuccess = false
				sendUpdate("Command exited with status \(result.exitcode)", true, false)
			}
		}

		sendUpdate("", false, overallSuccess)
	}
}

#else
public func runSwiftShell(
	commands: [String],
	update: @escaping (_ commandOutput: String, _ commandIsRunning: Bool, _ commandSucceeded: Bool?) -> Void
) {
	DispatchQueue.main.async {
		let message = commands.isEmpty
			? "No commands to run."
			: "Command execution is supported only on macOS."
		update(message, false, commands.isEmpty ? true : false)
	}
}
#endif
