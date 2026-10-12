//
//  WebRecordingInspector.swift
//  Reco
//

import SwiftUI

/// The selected clip's settings, and the page's: viewport, resolution and length.
struct WebRecordingInspector: View {
    @Bindable var viewModel: WebRecordingViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                if let clip = Binding(unwrapping: $viewModel.selectedPointerClip) {
                    InspectorSection(LocalizedStringKey(clip.wrappedValue.action.title)) {
                        InspectorField("Action") {
                            SegmentedChoice(selection: clip.action, options: PointerClip.Action.allCases.map { ($0, $0.title) })
                        }
                        InspectorField("Target") {
                            TextField("Target", text: clip.target.selector.orEmpty, prompt: Text("CSS selector"))
                                .font(.theme(.body, .mono))
                            Button(viewModel.isPicking ? "Stop Picking" : "Pick in Page", systemImage: "scope") {
                                viewModel.togglePicking()
                            }
                            .frame(maxWidth: .infinity)
                        }
                        if clip.wrappedValue.action == .type {
                            InspectorField("Text") {
                                TextField("Text", text: clip.text.orEmpty, prompt: Text("What to type"), axis: .vertical)
                                    .lineLimit(1...4)
                            }
                        }
                        InspectorField("Show") {
                            TextField("Show", text: clip.show.orEmpty, prompt: Text("CSS selector to zoom on"))
                                .font(.theme(.body, .mono))
                        }
                        InspectorField("Zoom") {
                            SegmentedChoice(selection: clip.zoom, options: [(nil, "Off")] + WebCamera.scales.map { (Double?.some($0), "\($0.formatted())×") })
                        }
                        WebClipTiming(viewModel: viewModel)
                    } footer: {
                        Text("""
                            The cursor is on the target from the clip's start to its end, and travels there \
                            before. A click presses at the start; typing clicks the field, then types the text \
                            through the clip. Show frames that element during the clip; once any clip shows one, \
                            only those zoom. Otherwise Zoom moves the camera in on the target just before the clip \
                            and out just after. Play shows both.
                            """)
                    }
                } else if let clip = Binding(unwrapping: $viewModel.selectedScrollClip) {
                    InspectorSection("Scroll") {
                        InspectorField("Scroll To") {
                            TextField("Scroll To", value: $viewModel.selectedScrollY, format: .number.precision(.fractionLength(0)), prompt: Text("Pixels from the top"))
                            Button("Use the Page's Position", systemImage: "arrow.down.to.line") {
                                Task {
                                    await viewModel.useCurrentScroll()
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                        InspectorField("Easing") {
                            Picker("Easing", selection: clip.easing) {
                                ForEach(Easing.allCases, id: \.self) { easing in
                                    Text(Self.name(of: easing)).tag(easing)
                                }
                            }
                            .labelsHidden()
                        }
                        WebClipTiming(viewModel: viewModel)
                    } footer: {
                        Text("The page scrolls from where the previous scroll left it, or the top.")
                    }
                } else {
                    InspectorSection("Clip") {
                        Label("Select a clip on the timeline to change it.", systemImage: "cursorarrow.click")
                            .foregroundStyle(EditorTheme.dim)
                    }
                }

                InspectorSection("Page") {
                    InspectorField("Viewport") {
                        Picker("Viewport", selection: $viewModel.viewport) {
                            ForEach(WebScript.Viewport.allCases, id: \.self) { viewport in
                                Text("\(Text(Self.name(of: viewport))) · \(Int(viewport.size.width))×\(Int(viewport.size.height))")
                                    .tag(Optional(viewport))
                            }
                        }
                        .labelsHidden()
                    }
                    InspectorField("Resolution") {
                        SegmentedChoice(selection: $viewModel.scale, options: [(1, "1×"), (2, "2×")])
                    }
                    InspectorSlider("Length", value: $viewModel.duration, in: WebScript.minimumDuration...WebScript.maximumDuration) {
                        Text("\($0, format: .number.precision(.fractionLength(1))) s")
                    }
                } footer: {
                    let size = viewModel.script.videoSize
                    Text("""
                        Renders \(Int(size.width))×\(Int(size.height)) at 60 fps, frame by frame: pages heavy with \
                        effects take longer than the video lasts.
                        """)
                }
            }
            .controlSize(.small)
        }
        .scrollIndicators(.never)
    }

    private static func name(of easing: Easing) -> LocalizedStringKey {
        switch easing {
        case .linear: "Linear"
        case .easeIn: "Ease In"
        case .easeOut: "Ease Out"
        case .easeInOut: "Ease In and Out"
        }
    }

    private static func name(of viewport: WebScript.Viewport) -> LocalizedStringKey {
        switch viewport {
        case .desktop: "Desktop"
        case .laptop: "Laptop"
        case .tablet: "Tablet"
        case .phone: "Phone"
        }
    }
}

/// The selected clip's start and length, in seconds.
private struct WebClipTiming: View {
    @Bindable var viewModel: WebRecordingViewModel

    var body: some View {
        HStack(spacing: EditorTheme.smallSpacing) {
            InspectorField("Start") {
                TextField("Start", value: $viewModel.selectionStart, format: .number.precision(.fractionLength(0...2)))
            }
            InspectorField("Length") {
                TextField("Length", value: $viewModel.selectionLength, format: .number.precision(.fractionLength(0...2)))
            }
        }
    }
}

private extension Binding where Value == String? {

    /// The text, empty for `nil`; setting it empty makes it `nil`.
    var orEmpty: Binding<String> {
        Binding<String> {
            wrappedValue ?? ""
        } set: {
            wrappedValue = $0.isEmpty ? nil : $0
        }
    }
}
