//
//  SensitiveMasks.swift
//  Reco
//

import CoreGraphics

/// Masks over private text found in frames sampled from a recording (spec 0004, N9). Pure.
nonisolated enum SensitiveMasks {

    /// The private text's boxes in one frame, as fractions of the video from its top-left corner.
    struct Sample: Equatable, Sendable {
        var time: Double
        var boxes: [CGRect]
    }

    /// Masks hiding every box in `samples` (in time order, one every `interval` seconds or so) for as long as it may
    /// show. A box in consecutive samples that overlaps the one before is the same text: one rectangle covering
    /// everywhere it was. Text is hidden from the sample before it was seen to the one after, since it can appear or
    /// go any time between, so what's missed is only what shows for less than `interval`. Rectangles that overlap in
    /// time share a mask, which spans them all.
    static func masks(from samples: [Sample], interval: Double, duration: Double) -> [MaskSegment] {
        var tracks: [Track] = []
        for (index, sample) in samples.enumerated() {
            for box in sample.boxes {
                let start = max(sample.time - interval, 0)
                let end = min(sample.time + interval, duration)
                guard start < end else { continue }
                // A track this sample extended ends at `index`, so another box in it can't take that track too
                if let track = tracks.lastIndex(where: { $0.lastSample == index - 1 && $0.rect.intersects(box) }) {
                    tracks[track].range = tracks[track].range.lowerBound..<end
                    tracks[track].rect = tracks[track].rect.union(box)
                    tracks[track].lastSample = index
                } else {
                    tracks.append(Track(range: start..<end, rect: box, lastSample: index))
                }
            }
        }
        return merging(tracks.map { MaskSegment(range: $0.range, rects: [$0.rect], kind: .pixelate) }, into: [])
    }

    /// One piece of text through the samples it showed in.
    private struct Track {
        var range: Range<Double>
        var rect: CGRect
        var lastSample: Int
    }

    /// `found` added to `masks`, sorted: masks that overlap in time join into one spanning them all, so nothing found
    /// is left out and masks stay apart. A group keeps the id and kind of its first mask from `masks`, so a mask made
    /// by hand stays selected and keeps its effect; otherwise of its first found one.
    static func merging(_ found: [MaskSegment], into masks: [MaskSegment]) -> [MaskSegment] {
        let all = masks.map { ($0, true) } + found.map { ($0, false) }
        let sorted = all.enumerated().sorted { ($0.element.0.range.lowerBound, $0.offset) < ($1.element.0.range.lowerBound, $1.offset) }
        var groups: [(mask: MaskSegment, isExisting: Bool)] = []
        for (mask, isExisting) in sorted.map(\.element) {
            guard let last = groups.last, mask.range.lowerBound < last.mask.range.upperBound else {
                groups.append((mask, isExisting))
                continue
            }
            var joined = isExisting && !last.isExisting ? mask : last.mask
            joined.range = min(last.mask.range.lowerBound, mask.range.lowerBound)..<max(last.mask.range.upperBound, mask.range.upperBound)
            joined.rects = last.mask.rects + mask.rects
            groups[groups.count - 1] = (joined, last.isExisting || isExisting)
        }
        return groups.map(\.mask)
    }
}
