//
//  GIFFrame.swift
//  Reco
//
//  Created by Diip3sh on 02.10.26.
//

import Foundation

/// One frame of an animated GIF, taken out of a single-image GIF file, and the bytes of the
/// animation around it.
///
/// ImageIO keeps every frame of an animation until it's finalized: 750 frames of 960×540 peaked at
/// 3.1 GB (M5, macOS 26.5). Encoding each frame as its own GIF and joining them here keeps the
/// writer's memory at one frame, at the same 8 ms per frame.
nonisolated struct GIFFrame: Equatable, Sendable {

    /// The image descriptor's position and size: x, y, width and height, 2 bytes each.
    let bounds: Data

    /// Red, green and blue per color; 2, 4, 8 … 256 colors.
    let palette: Data

    /// The LZW code size and the image's data blocks, with their terminator.
    let pixels: Data

    let isInterlaced: Bool

    /// The palette's entry that is see-through, if any.
    let transparentIndex: UInt8?

    /// The longest a frame can show, in hundredths of a second.
    static let maximumDelay = Int(UInt16.max)

    /// - Returns: `nil` unless `file` is a GIF with an image that has a palette.
    init?(file: Data) {
        let bytes = [UInt8](file)
        guard bytes.count > 13, bytes.starts(with: Array("GIF8".utf8)) else { return nil }
        var index = 13
        var palette = Self.table(in: bytes, at: &index, packed: bytes[10])
        var transparentIndex: UInt8?

        while index < bytes.count {
            switch bytes[index] {
            case 0x21:
                // A graphic control extension says which color is see-through
                if index + 6 < bytes.count, bytes[index + 1] == 0xF9, bytes[index + 3] & 1 == 1 {
                    transparentIndex = bytes[index + 6]
                }
                index += 2
                guard Self.skipBlocks(in: bytes, at: &index) else { return nil }
            case 0x2C:
                guard index + 10 <= bytes.count else { return nil }
                let packed = bytes[index + 9]
                bounds = Data(bytes[index + 1..<index + 9])
                index += 10
                if let local = Self.table(in: bytes, at: &index, packed: packed) {
                    palette = local
                }
                let start = index
                index += 1
                guard let palette, Self.skipBlocks(in: bytes, at: &index) else { return nil }
                self.palette = palette
                pixels = Data(bytes[start..<index])
                isInterlaced = packed & 0x40 != 0
                self.transparentIndex = transparentIndex
                return
            default:
                return nil
            }
        }
        return nil
    }

    /// The start of an animation `width` by `height` pixels that loops forever.
    static func header(width: Int, height: Int) -> Data {
        var data = Data("GIF89a".utf8)
        data.append(contentsOf: [UInt8(width & 0xFF), UInt8(width >> 8), UInt8(height & 0xFF), UInt8(height >> 8), 0, 0, 0])
        data.append(contentsOf: [0x21, 0xFF, 11])
        data.append(contentsOf: Array("NETSCAPE2.0".utf8))
        data.append(contentsOf: [3, 1, 0, 0, 0])
        return data
    }

    /// The end of an animation.
    static let trailer = Data([0x3B])

    /// The frame as part of an animation, shown for `delay` hundredths of a second.
    func block(delay: Int) -> Data {
        let delay = min(max(delay, 0), Self.maximumDelay)
        // Left in place when the next frame is drawn
        var data = Data([0x21, 0xF9, 4, 0x04 | (transparentIndex == nil ? 0 : 1), UInt8(delay & 0xFF), UInt8(delay >> 8), transparentIndex ?? 0, 0])
        data.append(0x2C)
        data.append(bounds)
        // A palette of 2^(n + 1) colors is stored as n
        let size = UInt8((palette.count / 3).trailingZeroBitCount - 1)
        data.append(0x80 | (isInterlaced ? 0x40 : 0) | size)
        data.append(palette)
        data.append(pixels)
        return data
    }

    /// The color table a `packed` byte announces at `index`, which moves past it.
    private static func table(in bytes: [UInt8], at index: inout Int, packed: UInt8) -> Data? {
        guard packed & 0x80 != 0 else { return nil }
        let length = 3 << (Int(packed & 7) + 1)
        guard index + length <= bytes.count else { return nil }
        defer { index += length }
        return Data(bytes[index..<index + length])
    }

    /// Moves `index` past data blocks and their terminator. False when they run off the end.
    private static func skipBlocks(in bytes: [UInt8], at index: inout Int) -> Bool {
        while index < bytes.count {
            let length = Int(bytes[index])
            index += length + 1
            if length == 0 {
                return index <= bytes.count
            }
        }
        return false
    }
}
