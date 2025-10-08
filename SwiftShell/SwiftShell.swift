//
//  SwiftShell.swift
//  SwiftShell
//
//  Created by Adon Omeri on 8/10/2025.
//

import Foundation
#if canImport(SwiftShell)
	internal import SwiftShell

	func runSwiftShell(
		commands _: [String],
		update _: @escaping (_ commandOutput: String, _ commandIsRunning: Bool, _ commandSucceeded: Bool?) -> Void
	) {
		DispatchQueue.global(qos: .userInitiated).async {
			let lines = snippet.content
				.split(separator: "\n")
				.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
				.filter { !$0.isEmpty }

			for line in lines {
				let parts = line.split(separator: " ").map { String($0) }
				guard let executable = parts.first else { continue }
				let args = Array(parts.dropFirst())

				// Check if executable exists
				let whichResult = run("/usr/bin/which", executable)
				if !whichResult.succeeded {
					DispatchQueue.main.async {
						commandOutput.append("Executable not found: \(executable)\n")
						commandSucceeded = false
						commandIsRunning = false
					}
					continue
				}

				do {
					let command = runAsync(executable, args)

					// stdout
					DispatchQueue.global(qos: .utility).async {
						for l in command.stdout.lines() {
							DispatchQueue.main.async {
								commandOutput.append(l + "\n")
								if commandOutput.count > 5000 {
									commandOutput.removeFirst(commandOutput.count - 5000)
								}
							}
						}
					}

					// stderr
					DispatchQueue.global(qos: .utility).async {
						for l in command.stderror.lines() {
							DispatchQueue.main.async {
								commandOutput.append("[stderr] " + l + "\n")
								if commandOutput.count > 5000 {
									commandOutput.removeFirst(commandOutput.count - 5000)
								}
							}
						}
					}

					try command.finish()

					DispatchQueue.main.async {
						commandSucceeded = command.exitcode() == 0
					}
				} catch {
					DispatchQueue.main.async {
						commandOutput.append("Failed to run command '\(line)': \(error)\n")
						commandSucceeded = false
					}
				}
			}

			DispatchQueue.main.async {
				commandIsRunning = false
			}
		}
	}

#endif
