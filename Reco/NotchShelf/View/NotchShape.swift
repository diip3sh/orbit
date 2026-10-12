//
//  NotchShape.swift
//  Reco
//

import SwiftUI

/// The notch shelf's outline: flush with the top edge, its top corners curving inward (the "ears" where it
/// meets the menu bar, so it reads as growing out of it), straight sides inset by `topRadius`, and its
/// bottom corners rounded outward. Both radii animate with the frame; they are clamped to fit a small rect.
nonisolated struct NotchShape: Shape {
    var topRadius: CGFloat
    var bottomRadius: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(topRadius, bottomRadius) }
        set {
            topRadius = newValue.first
            bottomRadius = newValue.second
        }
    }

    /// The radii that fit `rect`: the ears take at most half the height and width, the bottom corners the rest
    func fittedRadii(in rect: CGRect) -> (top: CGFloat, bottom: CGFloat) {
        let top: CGFloat = max(0, min(topRadius, rect.height / 2, rect.width / 2))
        let bottom: CGFloat = max(0, min(bottomRadius, rect.height - top, (rect.width - top * 2) / 2))
        return (top, bottom)
    }

    func path(in rect: CGRect) -> Path {
        let radii = fittedRadii(in: rect)
        let top = radii.top
        let bottom = radii.bottom
        let left: CGFloat = rect.minX + top
        let right: CGFloat = rect.maxX - top

        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: right, y: rect.minY + top), control: CGPoint(x: right, y: rect.minY))
        path.addLine(to: CGPoint(x: right, y: rect.maxY - bottom))
        path.addQuadCurve(to: CGPoint(x: right - bottom, y: rect.maxY), control: CGPoint(x: right, y: rect.maxY))
        path.addLine(to: CGPoint(x: left + bottom, y: rect.maxY))
        path.addQuadCurve(to: CGPoint(x: left, y: rect.maxY - bottom), control: CGPoint(x: left, y: rect.maxY))
        path.addLine(to: CGPoint(x: left, y: rect.minY + top))
        path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.minY), control: CGPoint(x: left, y: rect.minY))
        path.closeSubpath()
        return path
    }
}
