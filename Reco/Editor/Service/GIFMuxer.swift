//
//  GIFMuxer.swift
//  Reco
//
//  Created by Diip3sh on 07.10.26.
//

import Foundation

/// Joins single-frame GIFs, as ImageIO writes them, into one animated GIF a frame at a time.
///
/// ImageIO can write an animation itself, but it keeps every frame's bitmap until the file is finished: 900
/// frames of 1786×1080 took 19 GB (30 s at 30 fps, measured on macOS 26.6), where this peaked 54 MB above idle. So each frame is
/// encoded on its own (ImageIO's color quantizer and LZW) and only the blocks that carry a frame's pixels are
/// copied here, under a header with the size and a loop count, each frame after its delay.
nonisolated enum GIFMuxer {

    /// The signature, the screen's size, and the extension that makes it loop forever.
    static func header(width: Int, height: Int) -> Data {
        var data = Data("GIF89a".utf8)
        data += littleEndian(width) + littleEndian(height)
        // No global color table: every frame has its own
        data += [0x00, 0x00, 0x00]
        // NETSCAPE2.0 application extension, loop count 0: forever
        data += [0x21, 0xFF, 0x0B] + Data("NETSCAPE2.0".utf8) + [0x03, 0x01, 0x00, 0x00, 0x00]
        return data
    }

    static let trailer = Data([0x3B])

    /// The animation's next frame: the pixels of a one-frame GIF shown for `delay` centiseconds, drawn over
    /// the last one (disposal method 1). `nil` if `single` isn't a GIF with an image in it.
    static func frame(from single: Data, delay: Int) -> Data? {
        let bytes = [UInt8](single)
        guard bytes.count > 13, bytes.starts(with: Array("GIF".utf8)) else { return nil }
        // The screen's global color table, if any, is what a frame without a table of its own uses
        var position = 13
        var table: ArraySlice<UInt8>?
        if bytes[10] & 0x80 != 0 {
            guard let global = colorTable(in: bytes, at: position, bits: bytes[10] & 7) else { return nil }
            (table, position) = (global, position + global.count)
        }
        // Extensions before the image: a label, then sub-blocks up to an empty one
        while position + 1 < bytes.count, bytes[position] == 0x21 {
            position = endOfSubBlocks(in: bytes, from: position + 2)
        }
        guard position + 10 <= bytes.count, bytes[position] == 0x2C else { return nil }
        let descriptor = Array(bytes[position..<position + 10])
        position += 10
        if descriptor[9] & 0x80 != 0 {
            guard let local = colorTable(in: bytes, at: position, bits: descriptor[9] & 7) else { return nil }
            (table, position) = (local, position + local.count)
        }
        // The minimum code size, then the compressed pixels in sub-blocks
        let end = endOfSubBlocks(in: bytes, from: position + 1)
        guard let table, end <= bytes.count else { return nil }

        var frame = Data([0x21, 0xF9, 0x04, 0x04]) + littleEndian(delay) + [0x00, 0x00]
        // The image descriptor, with the table as the frame's own (2^(bits + 1) colors), and its interlacing kept
        let bits = UInt8((table.count / 3).trailingZeroBitCount - 1)
        frame += descriptor[0..<9] + [0x80 | (descriptor[9] & 0x40) | bits]
        frame += table + bytes[position..<end]
        return frame
    }

    /// The color table at `position`: 3 bytes for each of 2^(bits + 1) colors.
    private static func colorTable(in bytes: [UInt8], at position: Int, bits: UInt8) -> ArraySlice<UInt8>? {
        let end = position + 3 << (Int(bits) + 1)
        return end <= bytes.count ? bytes[position..<end] : nil
    }

    /// The index after the sub-blocks that start at `start`: each is a length and that many bytes, ending with a
    /// length of 0.
    private static func endOfSubBlocks(in bytes: [UInt8], from start: Int) -> Int {
        var position = start
        while position < bytes.count, bytes[position] != 0 {
            position += Int(bytes[position]) + 1
        }
        return position + 1
    }

    private static func littleEndian(_ value: Int) -> Data {
        Data([UInt8(value & 0xFF), UInt8((value >> 8) & 0xFF)])
    }
}
