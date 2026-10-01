//
//  Checkerboard.swift
//  Reco
//
//  Created by Diip3sh on 28.09.26.
//

import SwiftUI

/// Grey squares, the usual picture of transparency.
struct Checkerboard: View {
    var square: CGFloat = 6

    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(white: 0.32))
            var squares = Path()
            for row in 0..<Int((size.height / square).rounded(.up)) {
                for column in stride(from: row % 2, to: Int((size.width / square).rounded(.up)), by: 2) {
                    squares.addRect(CGRect(x: CGFloat(column) * square, y: CGFloat(row) * square, width: square, height: square))
                }
            }
            context.fill(squares, with: .color(white: 0.22))
        }
    }
}
