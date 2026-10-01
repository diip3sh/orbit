//
//  URL+RecoPaths.swift
//  Reco
//

import Darwin
import Foundation

extension URL {

    /// The user's home folder from the password database, which ignores `$HOME`: a coding agent that
    /// starts Reco with `--mcp` may have changed it.
    nonisolated static let userHome = URL(filePath: getpwuid(getuid()).map { String(cString: $0.pointee.pw_dir) } ?? NSHomeDirectory())

    /// Reco's own folder in Application Support: the saved web script and the agent socket.
    nonisolated static let recoSupport = userHome
        .appending(path: "Library/Application Support")
        .appending(path: Bundle.main.bundleIdentifier ?? "com.diip3sh.Reco")
}
