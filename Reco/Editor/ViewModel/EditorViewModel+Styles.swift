//
//  EditorViewModel+Styles.swift
//  Reco
//

import Foundation

extension EditorViewModel {

    /// The saved style the project looks like, if any: what the Style menu ticks, shares and deletes.
    var currentStyle: StylePreset? {
        stylePresets.first { $0.matches(project) }
    }

    /// Puts the project in `preset`'s look, one undo step; the recording's cuts, zooms, masks, crop and audio stay.
    func apply(_ preset: StylePreset) {
        edit("Apply Style") { $0 = preset.applied(to: $0) }
    }

    /// Saves the project's look under `name`, replacing a style of the same name. A blank name saves nothing.
    func saveStyle(named name: String) {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        do {
            try StylePresetStore.save(StylePreset(name: name, of: project))
            stylePresets = StylePresetStore.list()
        } catch {
            fail(.styleNotSaved(error))
        }
    }

    func deleteStyle(_ preset: StylePreset) {
        do {
            try StylePresetStore.delete(preset)
            stylePresets = StylePresetStore.list()
        } catch {
            fail(.styleNotSaved(error))
        }
    }

    /// Reads the style in the file at `url` (picked, dropped or opened), keeps it with the saved styles and applies it.
    func importStyle(from url: URL) {
        do {
            let preset = try StylePresetStore.read(from: url)
            try StylePresetStore.save(preset)
            stylePresets = StylePresetStore.list()
            apply(preset)
        } catch {
            fail(.unreadableStyle(error))
        }
    }

    /// The file `preset` is kept in, to share.
    nonisolated func styleFile(for preset: StylePreset) -> URL {
        StylePresetStore.url(of: preset)
    }
}
