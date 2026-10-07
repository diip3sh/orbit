//
//  FilePasteboard.swift
//  Reco
//
//  Created by Diip3sh on 07.10.26.
//

import AppKit

/// Puts a file on the pasteboard: its URL, for Finder and apps that take files, and for a GIF its data too, so
/// chat and design apps paste it as an animated image.
enum FilePasteboard {

    static let gifType = NSPasteboard.PasteboardType("com.compuserve.gif")

    static func copy(file url: URL, to pasteboard: NSPasteboard = .general) {
        // One item with every type, so a paste picks whichever it understands
        let item = NSPasteboardItem()
        item.setString(url.absoluteString, forType: .fileURL)
        if url.pathExtension == "gif", let data = try? Data(contentsOf: url) {
            item.setData(data, forType: gifType)
        }
        pasteboard.clearContents()
        pasteboard.writeObjects([item])
    }
}
