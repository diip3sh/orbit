//
//  WebRecordingViewModel+Clips.swift
//  Reco
//

import Foundation

/// Stepping through the script's clips in the inspector, and the selected clip's end.
extension WebRecordingViewModel {

    /// Every clip on both lanes, by when it starts; a cursor clip before a scroll that starts with it.
    var clipOrder: [UUID] {
        let starts = script.pointer.map { ($0.range.lowerBound, $0.id) } + script.scrolls.map { ($0.range.lowerBound, $0.id) }
        // `sorted` is stable, so ties keep the cursor lane first
        return starts.sorted { $0.0 < $1.0 }.map(\.1)
    }

    /// The selected clip's place in ``clipOrder``, from 0.
    var selectedClipIndex: Int? {
        selection.flatMap { clipOrder.firstIndex(of: $0) }
    }

    /// Whether there is a clip `offset` places from the selected one; with none selected, any clip.
    func canSelectClip(by offset: Int) -> Bool {
        let order = clipOrder
        guard let index = selectedClipIndex else { return !order.isEmpty }
        return order.indices.contains(index + offset)
    }

    /// Selects the clip `offset` places from the selected one in ``clipOrder``; with none selected, the first
    /// going forward or the last going back.
    func selectClip(by offset: Int) {
        let order = clipOrder
        guard !order.isEmpty else { return }
        let index = selectedClipIndex.map { $0 + offset } ?? (offset > 0 ? 0 : order.count - 1)
        guard order.indices.contains(index) else { return }
        selection = order[index]
    }

    /// Where the selected clip ends, for the inspector. Setting it moves the clip's end; its start stays.
    var selectionEnd: Double {
        get { selectionStart + selectionLength }
        set { selectionLength = newValue - selectionStart }
    }
}
