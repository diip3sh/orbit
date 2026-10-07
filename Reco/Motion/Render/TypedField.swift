//
//  TypedField.swift
//  Reco
//

import CoreImage

/// A field being typed into (``MotionAsset/typing``) as a `ui` layer shows it: its lifts drawn once,
/// and when each key and each settled result comes, in the layer's canvas pixels from its top-left
/// corner and seconds into its scene. The lifts keep their own pixels: at a whole scale every part of
/// the element lands on whole pixels, so its rows and results line up exactly, and the projection is
/// the one resampling, as in the film.
nonisolated struct TypedField: Sendable {

    /// The whole element as it shows from `time`: empty first, then with each word's results.
    nonisolated struct State: Sendable {
        let time: Double
        let height: Double
        let image: CIImage
    }

    /// When each character is typed; empty if it never is.
    let keys: [Double]

    let states: [State]

    /// The field's row with each length of the text typed, from 0, where it's the empty element's.
    let rows: [CIImage]

    let row: CGRect

    /// Where the text ends at each length, from 0 (where it starts), its centre line and its size.
    let ends: [Double]
    let line: Double
    let fontSize: Double

    /// When the layer first shows: the caret blinks from then until the first key.
    var shown = 0.0

    /// The whole element with the selection moved down once, twice…, once the text is typed; the
    /// arrow keys pressed in it, and where the selected result's centre is after each number of presses
    /// down, from none.
    let selected: [CIImage]
    let presses: [UIContent.Press]
    let selections: [Double]

    /// Image pixels per canvas pixel: the lifts' scale.
    let scale: Double

    /// The typing `layer` shows `asset` doing as `content` has it, from its lifts at `lift`'s scale;
    /// `nil` until all its lifts are taken.
    init?(_ asset: MotionAsset, showing content: UIContent, lift: UILiftCache.Lift, layer: MotionPlan.Layer, bundle: URL) {
        guard let text = asset.typing?.text, let lifted = UILiftCache.typing(asset, in: bundle), lifted.ends.count == text.count + 1,
              lifted.settled.count == lifted.heights.count else { return nil }
        let start = content.typingStart
        // Canvas pixels per CSS pixel, and image pixels per CSS pixel
        let css = layer.size.width / lift.size.width
        let scale = Double(lift.scale)
        let pixels = { (width: Double, height: Double) in CGSize(width: width * scale, height: height * scale) }
        let keys = start.map { HumanTyping.keyTimes(for: text, from: $0) } ?? []
        guard let empty = MotionPlan.picture(at: lift.url, pixels: pixels(lift.size.width, lift.size.height)) else { return nil }
        var states = [State(time: -.infinity, height: lift.size.height * css, image: empty)]
        for (length, height) in zip(lifted.settled, lifted.heights) where length <= keys.count {
            let url = UILiftCache.settledURL(of: asset, length: length, scale: lift.scale, in: bundle)
            guard let image = MotionPlan.picture(at: url, pixels: pixels(lift.size.width, height)) else { return nil }
            states.append(State(time: keys[length - 1] + HumanTyping.settleDelay, height: height * css, image: image))
        }
        // The empty element's row, in its whole pixels from the top
        let top = (lifted.row.minY * scale).rounded()
        var rows = [empty.cropped(to: CGRect(
            x: (lifted.row.minX * scale).rounded(), y: empty.extent.height - top - (lifted.row.height * scale).rounded(),
            width: (lifted.row.width * scale).rounded(), height: (lifted.row.height * scale).rounded()
        ))]
        for length in stride(from: 1, through: keys.count, by: 1) {
            let url = UILiftCache.typedURL(of: asset, length: length, scale: lift.scale, in: bundle)
            guard let row = MotionPlan.picture(at: url, pixels: pixels(lifted.row.width, lifted.row.height)) else { return nil }
            rows.append(row)
        }
        // The selection, if the layer moves it
        let presses = (content.presses ?? []).sorted { $0.time < $1.time }
        let most = asset.typing?.select ?? 0
        var selected: [CIImage] = []
        if !presses.isEmpty {
            guard most > 0, let selections = lifted.selections, selections.count == most + 1 else { return nil }
            for index in 1...most {
                let url = UILiftCache.selectedURL(of: asset, presses: index, scale: lift.scale, in: bundle)
                guard let image = MotionPlan.picture(at: url, pixels: pixels(lift.size.width, lifted.heights.last ?? lift.size.height)) else { return nil }
                selected.append(image)
            }
        }
        self.selected = selected
        self.presses = presses
        selections = (lifted.selections ?? []).map { $0 * css }
        self.scale = scale / css
        self.keys = keys
        self.states = states
        self.rows = rows
        row = CGRect(x: lifted.row.minX * css, y: lifted.row.minY * css, width: lifted.row.width * css, height: lifted.row.height * css)
        ends = lifted.ends.map { $0 * css }
        line = lifted.line * css
        fontSize = lifted.fontSize * css
    }

    /// How much of the text is typed at `time`.
    func length(at time: Double) -> Int {
        keys.partitioningIndex { $0 > time }
    }

    /// The state showing at `time`.
    func state(at time: Double) -> Int {
        max(states.partitioningIndex { $0.time > time } - 1, 0)
    }

    /// How many results under the first the selection is at `time`.
    func selection(at time: Double) -> Int {
        presses.prefix { $0.time <= time }.reduce(0) { index, press in
            min(max(index + (press.key == .arrowDown ? 1 : -1), 0), selected.count)
        }
    }

    /// How much of the selection's move the camera follows: the film's kept 95 % of the way, so the
    /// selected result crept 30 px down the frame (at 10× on 1080p) with each press, read as followed
    /// rather than locked.
    static let followShare = 0.95

    /// The camera's moves following the selection, each how much further down it looks in canvas pixels:
    /// from 0.06 s after each press, easing out over 0.3 s, as the film's camera followed it a beat late.
    /// Added up, presses closer than the move overlap smoothly.
    func follow() -> [PropertyTrack] {
        guard selections.count == selected.count + 1 else { return [] }
        var tracks: [PropertyTrack] = []
        var index = 0
        for press in presses {
            let next = min(max(index + (press.key == .arrowDown ? 1 : -1), 0), selected.count)
            if next != index {
                tracks.append(PropertyTrack(
                    .positionY, from: Keyframe(time: press.time + 0.06, value: 0, easing: .cubicBezier(0.15, 0.6, 0.25, 1)),
                    to: Keyframe(time: press.time + 0.36, value: Self.followShare * (selections[next] - selections[index]))
                ))
            }
            index = next
        }
        return tracks
    }

    /// How tall the element is at `time`: growing on a spring to each state's height from the last.
    func height(at time: Double) -> Double {
        let index = state(at: time)
        guard index > 0 else { return states[0].height }
        let (last, next) = (states[index - 1].height, states[index].height)
        return last + (next - last) * HumanTyping.growth(after: time - states[index].time)
    }

    /// The caret at `time`: its frame in canvas pixels and its opacity. It sits 0.037 of the font's size
    /// past the text, or 0.097 before the placeholder in an empty field, as Raycast's film shows it,
    /// 0.077 wide and 1.27 tall: the film's 1.15 by 19 px for Supabase's 15 px search.
    func caret(at time: Double) -> (frame: CGRect, opacity: Double) {
        let length = length(at: time)
        let size = CGSize(width: 0.077 * fontSize, height: 1.27 * fontSize)
        let left = length > 0 ? ends[length] + 0.037 * fontSize : ends[0] - 0.097 * fontSize - size.width
        let since = length > 0 ? keys[length - 1] : shown
        return (CGRect(x: left, y: line - size.height / 2, width: size.width, height: size.height), HumanTyping.caretOpacity(at: time, since: since))
    }
}
