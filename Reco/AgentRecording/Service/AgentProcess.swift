//
//  AgentProcess.swift
//  Reco
//

import Darwin
import Foundation
import OSLog
import Synchronization

/// Runs a command line to its end, with a time limit and cancellation, keeping the end of what it
/// printed (spec 0007). Used for the agents and for asking the login shell for its environment.
/// Output is never logged: it may hold anything the agent saw.
nonisolated enum AgentProcess {

    struct Result: Sendable {
        var end: AgentProcessEnd
        var stdout: String
        var stderr: String
    }

    enum EnvironmentError: LocalizedError {
        case timedOut
        case unreadable

        var errorDescription: String? {
            switch self {
            case .timedOut: "Your shell took more than 10 seconds to start."
            case .unreadable: "Reco couldn't read your shell's environment."
            }
        }
    }

    private static let killDelay = Duration.seconds(3)
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Reco", category: "AgentProcess")

    /// The child and what the callbacks around it share.
    ///
    /// ponytail: `Process` isn't `Sendable`. Here it's started once, then only terminated and asked
    /// whether it runs, from other threads, which it allows. The upgrade path is the `Subprocess`
    /// package.
    private final class Child: @unchecked Sendable {
        let process = Process()
        let stdout: Mutex<OutputTail>
        let stderr = Mutex(OutputTail())
        private let stopped = Mutex<AgentProcessEnd?>(nil)

        init(outputLimit: Int) {
            stdout = Mutex(OutputTail(limit: outputLimit))
        }

        func append(_ data: Data, toErrors: Bool) {
            if toErrors {
                stderr.withLock { $0.append(data) }
            } else {
                stdout.withLock { $0.append(data) }
            }
        }

        /// Why it was stopped, if it was.
        var stopReason: AgentProcessEnd? {
            stopped.withLock { $0 }
        }

        /// Asks it to end, and makes it if it hasn't after a few seconds. The first reason stays.
        func stop(because reason: AgentProcessEnd) {
            stopped.withLock { $0 = $0 ?? reason }
            guard process.isRunning else { return }
            process.terminate()
            Task {
                try? await Task.sleep(for: killDelay)
                if process.isRunning {
                    kill(process.processIdentifier, SIGKILL)
                }
            }
        }
    }

    /// Runs `executable` in `directory` with exactly `environment`, and nothing on stdin.
    static func run(
        executable: URL, arguments: [String], environment: [String: String], directory: URL,
        timeout: Duration, outputLimit: Int = OutputTail.defaultLimit
    ) async -> Result {
        let child = Child(outputLimit: outputLimit)
        let process = child.process
        process.executableURL = executable
        process.arguments = arguments
        process.environment = environment
        process.currentDirectoryURL = directory
        process.standardInput = FileHandle.nullDevice
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        collect(outputPipe.fileHandleForReading, from: child, toErrors: false)
        collect(errorPipe.fileHandleForReading, from: child, toErrors: true)

        let start = ContinuousClock.now
        let timer = Task {
            try await Task.sleep(for: timeout)
            child.stop(because: .timedOut)
        }
        let end: AgentProcessEnd = await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                process.terminationHandler = { finished in
                    drain(outputPipe.fileHandleForReading, from: child, toErrors: false)
                    drain(errorPipe.fileHandleForReading, from: child, toErrors: true)
                    continuation.resume(returning: child.stopReason ?? .exited(finished.terminationStatus))
                }
                do {
                    try process.run()
                } catch {
                    process.terminationHandler = nil
                    continuation.resume(returning: .launchFailed("Reco couldn't start \(executable.lastPathComponent): \(error.localizedDescription)"))
                    return
                }
                // Cancelled or timed out before it started
                if let reason = child.stopReason {
                    child.stop(because: reason)
                }
            }
        } onCancel: {
            child.stop(because: .cancelled)
        }
        timer.cancel()
        logger.info("\(executable.lastPathComponent) ended after \(start.duration(to: .now).formatted(.units(allowed: [.seconds], width: .narrow)))")
        return Result(end: end, stdout: child.stdout.withLock { $0.text }, stderr: child.stderr.withLock { $0.text })
    }

    /// The login shell's environment (spec 0007), read every time the panel opens, since the user
    /// changes their startup files.
    static func loginEnvironment() async throws -> [String: String] {
        let shell = getpwuid(getuid()).map { String(cString: $0.pointee.pw_shell) } ?? "/bin/zsh"
        let result = await run(
            executable: URL(filePath: shell), arguments: ["-l", "-i", "-c", LoginEnvironment.command],
            environment: ProcessInfo.processInfo.environment, directory: .userHome, timeout: .seconds(10),
            outputLimit: 1 << 20
        )
        if result.end == .timedOut {
            throw EnvironmentError.timedOut
        }
        guard let environment = LoginEnvironment.parse(Data(result.stdout.utf8)) else { throw EnvironmentError.unreadable }
        return environment
    }

    // MARK: - Pipes

    private static func collect(_ handle: FileHandle, from child: Child, toErrors: Bool) {
        // read(2), not `availableData`: once `drain` has made the pipe non-blocking, a handler
        // already on its way reads EAGAIN, which `availableData` raises as an exception that
        // ended the app (seen in the test host)
        handle.readabilityHandler = { handle in
            var buffer = [UInt8](repeating: 0, count: 65_536)
            let count = read(handle.fileDescriptor, &buffer, buffer.count)
            if count > 0 {
                child.append(Data(buffer[..<count]), toErrors: toErrors)
            } else if count == 0 || errno != EAGAIN {
                handle.readabilityHandler = nil
            }
        }
    }

    /// Reads what's left without waiting for the pipe to close, which a process the agent left
    /// running would hold open.
    private static func drain(_ handle: FileHandle, from child: Child, toErrors: Bool) {
        handle.readabilityHandler = nil
        let descriptor = handle.fileDescriptor
        _ = fcntl(descriptor, F_SETFL, fcntl(descriptor, F_GETFL) | O_NONBLOCK)
        var buffer = [UInt8](repeating: 0, count: 8192)
        while true {
            let count = read(descriptor, &buffer, buffer.count)
            guard count > 0 else { break }
            child.append(Data(buffer[..<count]), toErrors: toErrors)
        }
    }
}
