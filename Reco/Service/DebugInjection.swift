//
//  DebugInjection.swift
//  Reco
//

#if DEBUG
import Foundation

/// Debug builds only: connects to the InjectionIII app (`brew install --cask injectioniii`) so saving
/// a Swift file patches the running app without a relaunch. The bundle is loaded from the app at run
/// time, so there's no package. Needs the Debug build's `-interposable` link flag and no hardened
/// runtime (library validation rejects the bundle). Does nothing when InjectionIII isn't installed.
enum DebugInjection {
    private static let bundlePath = "/Applications/InjectionIII.app/Contents/Resources/macOSInjection.bundle"

    static func load() {
        Bundle(path: bundlePath)?.load()
    }
}
#endif
