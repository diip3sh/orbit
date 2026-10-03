//
//  FolderWatcher.swift
//  Reco
//

import Foundation

/// Calls back when files are added to, removed from or renamed in some folders, so the Library shows
/// a recording or screenshot the moment it's saved (spec 0010). Folders that don't exist are skipped;
/// the Library also reads them again whenever its window comes forward.
@MainActor
final class FolderWatcher {

    private var sources: [any DispatchSourceFileSystemObject] = []
    private var pending: Task<Void, Never>?

    /// Changes this close together are one: a save writes the movie, then its sidecars.
    private static let settleTime = Duration.milliseconds(300)

    /// Watches `folders` until ``stop()`` or the next `watch`.
    func watch(_ folders: [URL], onChange: @escaping @MainActor () -> Void) {
        stop()
        for folder in Set(folders.map(\.standardizedFileURL)) {
            let descriptor = open(folder.path(percentEncoded: false), O_EVTONLY)
            guard descriptor >= 0 else { continue }
            let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: descriptor, eventMask: .write, queue: .main)
            source.setEventHandler { [weak self] in
                MainActor.assumeIsolated {
                    self?.changed(onChange)
                }
            }
            source.setCancelHandler { close(descriptor) }
            source.resume()
            sources.append(source)
        }
    }

    func stop() {
        pending?.cancel()
        sources.forEach { $0.cancel() }
        sources = []
    }

    private func changed(_ onChange: @escaping @MainActor () -> Void) {
        pending?.cancel()
        pending = Task {
            try? await Task.sleep(for: Self.settleTime)
            guard !Task.isCancelled else { return }
            onChange()
        }
    }
}
