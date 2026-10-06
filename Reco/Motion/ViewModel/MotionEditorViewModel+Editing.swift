//
//  MotionEditorViewModel+Editing.swift
//  Reco
//

import CoreGraphics
import Foundation
import OSLog

// MARK: - Editing

extension MotionEditorViewModel {

    /// Applies an edit as one undo step named `actionName`, previews it and saves it once edits
    /// settle. An edit that would make the document invalid isn't applied.
    ///
    /// With `coalescing`, an edit with the same name within a second of the previous one joins its
    /// undo step, so dragging a slider is undone at once.
    func edit(_ actionName: String, coalescing: Bool = false, _ change: (inout MotionDocument) -> Void) {
        guard let document else { return }
        var edited = document
        change(&edited)
        guard edited != document, (try? edited.validate()) != nil else { return }
        if !coalescedEdits.joinsPrevious(actionName, coalescing: coalescing) {
            undoManager.registerUndo(withTarget: self) { viewModel in
                viewModel.coalescedEdits.reset()
                viewModel.replace(with: document, actionName: actionName)
            }
            undoManager.setActionName(actionName)
        }
        self.document = edited
        documentChanged()
    }

    /// The selected scene, laid out with its shot: the layers the inspector lists.
    var laidOutScene: MotionScene? {
        guard let document, document.scenes.indices.contains(selectedScene) else { return nil }
        // Sizes move layers, never add or remove them
        return DocumentExpansion.laidOut(document, scene: selectedScene, sizes: [:])
    }

    /// The selected scene, for the inspector's controls. Each change is an edit.
    var scene: MotionScene? {
        get { document.flatMap { $0.scenes.indices.contains(selectedScene) ? $0.scenes[selectedScene] : nil } }
        set {
            guard let newValue else { return }
            edit("Scene", coalescing: true) { $0.scenes[selectedScene] = newValue }
        }
    }

    /// The selected layer as the scene shows it, for the inspector's controls. Changing one a shot
    /// laid out puts a copy in the scene's own layers, which replaces the shot's by its id.
    var layer: MotionLayer? {
        get { laidOutScene?.layers.first { $0.id == selectedLayer } }
        set {
            guard let newValue else { return }
            edit("Layer", coalescing: true) { document in
                var layers = document.scenes[selectedScene].layers
                if let index = layers.firstIndex(where: { $0.id == newValue.id }) {
                    layers[index] = newValue
                } else {
                    layers.append(newValue)
                }
                document.scenes[selectedScene].layers = layers
            }
        }
    }

    /// When `move` on `layer` starts and how long it takes, its defaults resolved as the plan
    /// resolves them.
    func timing(of move: MotionMove, on layer: MotionLayer) -> (start: Double, duration: Double) {
        var context = MoveContext(sceneDuration: scene?.duration ?? 0, canvas: document?.canvas.size ?? .zero)
        if case .text(let text) = layer.content {
            let measured = TextImage(text, scale: 0)
            (context.characters, context.lines) = (measured.characters.count, measured.lines.count)
        }
        return MoveExpansion.timing(of: move, in: context)
    }

    /// What the grammar's rules find in the document.
    var findings: [MotionLint.Finding] {
        document.map { MotionLint.findings(in: $0) } ?? []
    }

    /// Selects the scene and moves the playhead to its start.
    func select(scene index: Int) {
        guard let document, document.scenes.indices.contains(index) else { return }
        selectedScene = index
        selectedLayer = nil
        playback.seek(to: document.scenes[..<index].reduce(0) { $0 + $1.duration })
    }

    // MARK: - Private

    private func replace(with document: MotionDocument, actionName: String) {
        guard let current = self.document else { return }
        undoManager.registerUndo(withTarget: self) { viewModel in
            viewModel.coalescedEdits.reset()
            viewModel.replace(with: current, actionName: actionName)
        }
        undoManager.setActionName(actionName)
        self.document = document
        selectedScene = min(selectedScene, document.scenes.count - 1)
        documentChanged()
    }

    /// Previews the document as it is now, once edits pause for 0.15 s, and saves it after a second.
    private func documentChanged() {
        guard let document else { return }
        let time = playback.currentTime
        rebuild?.cancel()
        rebuild = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(150))
            guard let self, !Task.isCancelled else { return }
            do {
                try await preview(document, at: time)
            } catch where !(error is CancellationError) {
                logger.error("Couldn't preview the edit: \(error.localizedDescription, privacy: .public)")
            } catch {}
        }
        save?.cancel()
        let bundle = bundleURL
        save = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            do {
                try await MotionStore.write(document, to: bundle)
            } catch {
                self?.error = error.localizedDescription
            }
        }
    }
}
