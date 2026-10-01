//
//  ImagePasteboard.swift
//  Reco
//
//  Created by Diip3sh on 28.09.26.
//

import AppKit

/// Puts PNG data on the pasteboard, for apps that paste images (Slack, Messages, Figma, Preview).
enum ImagePasteboard {

    static func copy(png: Data, to pasteboard: NSPasteboard = .general) {
        pasteboard.clearContents()
        pasteboard.setData(png, forType: .png)
    }
}
