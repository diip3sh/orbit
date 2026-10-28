//
//  WebInspectorControls.swift
//  Reco
//

import SwiftUI

/// The Web Recording inspector's choice of a few options on one track, the chosen one on a raised fill that
/// slides to it: its tabs, and the page's resolution.
struct WebSegmentedTrack<Value: Hashable>: View {
    struct Option {
        let value: Value
        let title: LocalizedStringKey
        var symbol: String?
    }

    @Binding var selection: Value
    let options: [Option]

    @Namespace private var highlight

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options.indices, id: \.self) { index in
                let option = options[index]
                let isSelected = option.value == selection
                Button {
                    selection = option.value
                } label: {
                    HStack(spacing: 6) {
                        if let symbol = option.symbol {
                            Image(systemName: symbol)
                                .font(.system(size: 11, weight: .semibold))
                        }
                        Text(option.title)
                    }
                    .font(.theme(.body, weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(isSelected ? EditorTheme.ink : EditorTheme.dim)
                    .frame(maxWidth: .infinity, minHeight: 32)
                    .background {
                        if isSelected {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(EditorTheme.raised)
                                .strokeBorder(EditorTheme.hairline)
                                .matchedGeometryEffect(id: "highlight", in: highlight)
                        }
                    }
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(4)
        .webField(in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .editorMotion(EditorTheme.quickMotion, value: selection)
    }
}

/// One of a few choices as a 52 pt disc with its name under it, the chosen one ringed in the accent: a cursor
/// clip's action, a viewport, a scroll's easing.
struct WebChoiceButton<Icon: View>: View {
    let title: LocalizedStringKey
    var key: String?
    var caption: String?
    let isSelected: Bool
    let action: () -> Void
    @ViewBuilder let icon: Icon

    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: EditorTheme.smallSpacing) {
                icon
                    .foregroundStyle(isSelected ? EditorTheme.accent : isHovered && isEnabled ? EditorTheme.ink : EditorTheme.dim)
                    .frame(width: 52, height: 52)
                    .background(isSelected ? EditorTheme.accent.opacity(0.15) : WebPanel.fill, in: .circle)
                    .overlay {
                        Circle().strokeBorder(isSelected ? EditorTheme.accent : WebPanel.edge, lineWidth: isSelected ? 1.5 : 1)
                    }
                VStack(spacing: 2) {
                    HStack(spacing: 5) {
                        Text(title)
                            .font(.theme(.callout, weight: isSelected ? .semibold : nil))
                            .foregroundStyle(isSelected ? EditorTheme.ink : EditorTheme.dim)
                        if let key {
                            Text(key)
                                .font(.theme(.caption, .mono))
                                .foregroundStyle(EditorTheme.dim)
                        }
                    }
                    if let caption {
                        Text(caption)
                            .font(.theme(.caption, .mono))
                            .foregroundStyle(EditorTheme.dim)
                    }
                }
                .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .contentShape(.rect)
        }
        .buttonStyle(WebPressButtonStyle())
        .onHover { isHovered = $0 }
        .editorMotion(EditorTheme.quickMotion, value: isHovered)
        .editorMotion(EditorTheme.quickMotion, value: isSelected)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// A label that shrinks a little while pressed and dims when disabled, for buttons that draw their own look.
struct WebPressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        WebPress(configuration: configuration)
    }
}

private struct WebPress: View {
    let configuration: ButtonStyleConfiguration

    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        configuration.label
            .opacity(isEnabled ? 1 : 0.4)
            .scaleEffect(isEnabled && configuration.isPressed ? 0.96 : 1)
            .editorMotion(configuration.isPressed ? nil : EditorTheme.quickMotion, value: configuration.isPressed)
    }
}

/// A 44 pt field on the faint fill, in mono, with a control at its end (Pick, Use page).
struct WebInspectorField<Trailing: View>: View {
    let title: LocalizedStringKey
    @Binding var text: String
    let prompt: LocalizedStringKey
    var isMultiline = false
    @ViewBuilder let trailing: Trailing

    var body: some View {
        HStack(spacing: EditorTheme.smallSpacing) {
            TextField(title, text: $text, prompt: Text(prompt).foregroundStyle(EditorTheme.faint), axis: isMultiline ? .vertical : .horizontal)
                .textFieldStyle(.plain)
                .font(.theme(.body, isMultiline ? .sans : .mono))
                .lineLimit(isMultiline ? 1...4 : 1...1)
                .padding(.vertical, EditorTheme.mediumSpacing)
            trailing
        }
        .padding(.leading, EditorTheme.spacing)
        .padding(.trailing, 6)
        .frame(minHeight: 44)
        .webField(in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

extension WebInspectorField where Trailing == EmptyView {
    init(_ title: LocalizedStringKey, text: Binding<String>, prompt: LocalizedStringKey, isMultiline: Bool = false) {
        self.init(title: title, text: text, prompt: prompt, isMultiline: isMultiline) { EmptyView() }
    }
}

/// A number in large mono on a card, with its title above and unit after: a clip's start and end, the length.
struct WebNumberCard: View {
    let title: LocalizedStringKey
    @Binding var value: Double
    var unit = "s"

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.theme(.callout))
                .foregroundStyle(EditorTheme.dim)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                TextField(title, value: $value, format: .number.precision(.fractionLength(2)))
                    .textFieldStyle(.plain)
                    .font(.theme(.title, weight: .semibold, .mono))
                    .fixedSize()
                Text(unit)
                    .font(.theme(.body, .mono))
                    .foregroundStyle(EditorTheme.dim)
            }
        }
        .padding(EditorTheme.spacing)
        .frame(maxWidth: .infinity, alignment: .leading)
        .webField(in: RoundedRectangle(cornerRadius: WebPanel.radius, style: .continuous))
    }
}

/// A cursor clip's zoom as a ruler from 1× (no zoom) to 3×, a tick every 0.05× and a longer one every 0.5×, the
/// value in the accent. Dragging or clicking snaps to quarters.
struct WebZoomRuler: View {
    @Binding var zoom: Double?

    /// 1× is no zoom; 3× is ``WebCamera/maximumFitScale``, as far as a page rendered at 2× stays sharp.
    static let range = 1.0...WebCamera.maximumFitScale

    private static let snap = 0.25
    private static let tick = 0.05
    private static let labels: [Double] = [1, 1.5, 2, 2.5, 3]

    /// Room at each end, so the end labels centre on their ticks.
    private static let inset: CGFloat = 8

    var body: some View {
        VStack(spacing: 6) {
            GeometryReader { proxy in
                let span = proxy.size.width - 2 * Self.inset
                Canvas { context, size in
                    let count = Int(((Self.range.upperBound - Self.range.lowerBound) / Self.tick).rounded())
                    let value = zoom ?? 1
                    for index in 0...count {
                        let scale = Self.range.lowerBound + Double(index) * Self.tick
                        let isMajor = index.isMultiple(of: 10)
                        let height: CGFloat = isMajor ? 16 : 10
                        let tickX = Self.inset + span * CGFloat(Double(index) / Double(count))
                        let rect = CGRect(x: tickX - 0.5, y: (size.height - height) / 2, width: 1, height: height)
                        let opacity = scale <= value + 0.001 ? (isMajor ? 0.7 : 0.45) : (isMajor ? 0.35 : 0.18)
                        context.fill(Path(rect), with: .color(EditorTheme.ink.opacity(opacity)))
                    }
                    let markerX = Self.inset + span * CGFloat(Self.fraction(of: value))
                    let marker = CGRect(x: markerX - 1.5, y: 0, width: 3, height: size.height)
                    context.fill(Path(roundedRect: marker, cornerRadius: 1.5), with: .color(EditorTheme.accent))
                }
                .contentShape(.rect)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { drag in
                            set(Self.range.lowerBound + Double((drag.location.x - Self.inset) / span) * Self.length)
                        }
                )
            }
            .frame(height: 26)

            GeometryReader { proxy in
                let span = proxy.size.width - 2 * Self.inset
                ForEach(Self.labels, id: \.self) { label in
                    Text("\(label.formatted())×")
                        .font(.theme(.caption, .mono))
                        .foregroundStyle(EditorTheme.dim)
                        .fixedSize()
                        .position(x: Self.inset + span * CGFloat(Self.fraction(of: label)), y: proxy.size.height / 2)
                }
            }
            .frame(height: 12)
        }
        .pointerStyle(.columnResize)
        .accessibilityElement()
        .accessibilityLabel("Zoom")
        .accessibilityValue(zoom.map { "\($0.formatted())×" } ?? "Off")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: set((zoom ?? 1) + Self.snap)
            case .decrement: set((zoom ?? 1) - Self.snap)
            @unknown default: break
            }
        }
    }

    private static var length: Double {
        range.upperBound - range.lowerBound
    }

    private static func fraction(of scale: Double) -> Double {
        (min(max(scale, range.lowerBound), range.upperBound) - range.lowerBound) / length
    }

    /// Snapped to a quarter inside the range; 1× turns the zoom off.
    private func set(_ scale: Double) {
        let snapped = min(max((scale / Self.snap).rounded() * Self.snap, Self.range.lowerBound), Self.range.upperBound)
        let new: Double? = snapped > Self.range.lowerBound ? snapped : nil
        if new != zoom {
            zoom = new
        }
    }
}
