//
//  AnnotationCanvas.swift
//  Reco
//

import SwiftUI

/// The shot with its effects, the marks drawn over it by the shared renderer, and the field where text is typed.
/// Fills the width it's given at the shot's shape; gestures are turned into the shot's points.
struct AnnotationCanvas: View {

    let editor: AnnotationEditor

    /// Where the press being drawn started; a new start is a new press, so a gesture that was cancelled without
    /// ending (no `onEnded` then) can't swallow the next one
    @State private var pressStart: CGPoint?
    @FocusState private var isTextFocused: Bool

    var body: some View {
        GeometryReader { geometry in
            let scale = geometry.size.width / editor.pointSize.width
            ZStack(alignment: .topLeading) {
                Image(editor.base, scale: 1, label: Text("Screenshot"))
                    .resizable()
                Canvas(rendersAsynchronously: false) { context, _ in
                    context.withCGContext { cgContext in
                        cgContext.scaleBy(x: scale, y: scale)
                        AnnotationRenderer.draw(editor.document, selected: editor.selection, in: cgContext)
                        if let draft = editor.draft {
                            AnnotationRenderer.draw(draft, number: nil, in: cgContext)
                        }
                        if let crop = editor.cropDraft ?? editor.document.crop {
                            AnnotationRenderer.drawCropDim(crop, in: editor.pointSize, context: cgContext)
                        }
                    }
                }
                if let origin = editor.textOrigin {
                    textField(at: origin, scale: scale)
                }
            }
            .contentShape(.rect)
            .gesture(drawing(scale: scale))
        }
        .aspectRatio(editor.pointSize, contentMode: .fit)
    }

    /// A press begins a mark where it lands, every move extends it, and the release keeps it
    private func drawing(scale: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { value in
                if pressStart != value.startLocation {
                    pressStart = value.startLocation
                    editor.begin(at: point(value.startLocation, scale: scale))
                }
                editor.drag(to: point(value.location, scale: scale))
            }
            .onEnded { value in
                pressStart = nil
                editor.end(at: point(value.location, scale: scale))
            }
    }

    private func point(_ location: CGPoint, scale: CGFloat) -> CGPoint {
        CGPoint(
            x: min(max(location.x / scale, 0), editor.pointSize.width),
            y: min(max(location.y / scale, 0), editor.pointSize.height)
        )
    }

    /// Typed where it was clicked, at the size it will be drawn; Return keeps it, Esc drops it
    private func textField(at origin: CGPoint, scale: CGFloat) -> some View {
        let fontSize = Annotation.fontSize(for: editor.lineWidth) * scale
        return TextField("Text", text: Bindable(editor).text, axis: .vertical)
            .textFieldStyle(.plain)
            .font(.system(size: fontSize, weight: .bold))
            .foregroundStyle(Color(cgColor: editor.color.cgColor))
            .frame(minWidth: fontSize * 4, maxWidth: max(editor.pointSize.width - origin.x, fontSize * 4) * scale, alignment: .leading)
            .fixedSize(horizontal: true, vertical: true)
            .focused($isTextFocused)
            .onSubmit { editor.commitText() }
            .onExitCommand { editor.cancelText() }
            .onAppear { isTextFocused = true }
            // The field's ascent sits where the drawn text's will
            .offset(x: origin.x * scale - 2, y: origin.y * scale - fontSize * 0.1)
    }
}
