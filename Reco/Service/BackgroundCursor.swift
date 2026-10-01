//
//  BackgroundCursor.swift
//  Reco
//
//  Created by Diip3sh on 30.09.26.
//

import AppKit
import OSLog

/// Lets the app set the cursor while another app is frontmost.
///
/// macOS ignores `NSCursor.set()` from an app that isn't active. The window server has a switch for
/// it on each connection, `SetsCursorInBackground`, but no public API. Its two functions are looked
/// up at run time, so if a future macOS drops them the cursor just stays as the frontmost app left
/// it. Both are found and the call succeeds on macOS 27.0.1.
enum BackgroundCursor {

    private typealias MainConnection = @convention(c) () -> Int32
    private typealias SetConnectionProperty = @convention(c) (Int32, Int32, CFString, CFTypeRef) -> Int32

    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Reco", category: "BackgroundCursor")

    static func setEnabled(_ isEnabled: Bool) {
        // RTLD_DEFAULT, which Swift doesn't import
        let loadedImages = UnsafeMutableRawPointer(bitPattern: -2)
        guard let mainConnection = dlsym(loadedImages, "CGSMainConnectionID"),
              let setProperty = dlsym(loadedImages, "CGSSetConnectionProperty") else {
            logger.warning("Window server functions not found; the cursor can't be set in the background")
            return
        }

        let connection = unsafeBitCast(mainConnection, to: MainConnection.self)()
        let value: CFBoolean = isEnabled ? kCFBooleanTrue : kCFBooleanFalse
        let error = unsafeBitCast(setProperty, to: SetConnectionProperty.self)(
            connection, connection, "SetsCursorInBackground" as CFString, value
        )
        if error != 0 {
            logger.warning("Setting the cursor in the background failed: \(error)")
        }
    }
}
