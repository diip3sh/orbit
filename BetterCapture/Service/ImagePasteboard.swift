//
//  ImagePasteboard.swift
//  BetterCapture
//
//  Created by Diip3sh on 28.09.26.
//

import AppKit

/// Puts an image file on the pasteboard as one item: PNG data for apps that paste images
/// (Slack, Messages, Figma, Preview) and the file URL for Finder.
enum ImagePasteboard {

    static func copy(png: Data, fileURL: URL, to pasteboard: NSPasteboard = .general) {
        let item = NSPasteboardItem()
        item.setData(png, forType: .png)
        item.setString(fileURL.absoluteString, forType: .fileURL)

        pasteboard.clearContents()
        pasteboard.writeObjects([item])
    }
}
