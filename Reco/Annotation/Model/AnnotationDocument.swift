//
//  AnnotationDocument.swift
//  Reco
//

import CoreGraphics
import Foundation

/// Every mark on a screenshot, in the order they were added (the last is drawn on top), and its crop.
nonisolated struct AnnotationDocument: Equatable, Sendable {

    var annotations: [Annotation] = []

    /// The part of the shot kept, in its points; nil keeps it all. Applied after the marks, so they keep their places.
    var crop: CGRect?

    /// The smallest crop or shape, in points.
    static let minimumSize: CGFloat = 8

    var isEmpty: Bool {
        annotations.isEmpty && crop == nil
    }

    var hasEffects: Bool {
        annotations.contains(where: \.isEffect)
    }

    /// The effect marks' rectangles by kind, for `MaskRenderer`.
    var effects: [(kind: MaskSegment.Kind, rects: [CGRect])] {
        var blur: [CGRect] = []
        var pixelate: [CGRect] = []
        var spotlight: [CGRect] = []
        for annotation in annotations {
            switch annotation.shape {
            case .blur(let rect): blur.append(rect.standardized)
            case .pixelate(let rect): pixelate.append(rect.standardized)
            case .spotlight(let rect): spotlight.append(rect.standardized)
            default: break
            }
        }
        return [(.blur, blur), (.pixelate, pixelate), (.spotlight, spotlight)].filter { !$0.rects.isEmpty }
    }

    /// A step's number: its place among the steps, from 1, in the order they were added.
    func stepNumber(of annotation: Annotation) -> Int? {
        guard case .step = annotation.shape else { return nil }
        var number = 0
        for other in annotations {
            if case .step = other.shape {
                number += 1
            }
            if other.id == annotation.id {
                return number
            }
        }
        return nil
    }

    /// The topmost mark at `point`, if any.
    func annotation(at point: CGPoint) -> Annotation? {
        annotations.last { $0.contains(point) }
    }

    mutating func add(_ annotation: Annotation) {
        annotations.append(annotation)
    }

    /// Replaces the mark with `annotation`'s id; nothing when there's none.
    mutating func update(_ annotation: Annotation) {
        guard let index = annotations.firstIndex(where: { $0.id == annotation.id }) else { return }
        annotations[index] = annotation
    }

    mutating func remove(_ id: Annotation.ID) {
        annotations.removeAll { $0.id == id }
    }

    subscript(id: Annotation.ID) -> Annotation? {
        annotations.first { $0.id == id }
    }

    /// `rect` as a crop of a shot of `size`: standardized, inside the shot and at least `minimumSize` a side; nil when
    /// it's the whole shot, since that is no crop.
    static func crop(_ rect: CGRect, in size: CGSize) -> CGRect? {
        let bounds = CGRect(origin: .zero, size: size)
        var crop = rect.standardized.intersection(bounds)
        guard !crop.isNull else { return nil }
        crop.size.width = min(max(crop.width, minimumSize), size.width)
        crop.size.height = min(max(crop.height, minimumSize), size.height)
        crop.origin.x = min(crop.minX, size.width - crop.width)
        crop.origin.y = min(crop.minY, size.height - crop.height)
        return crop.integral == bounds.integral ? nil : crop
    }
}
