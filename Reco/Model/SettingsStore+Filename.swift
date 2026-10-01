//
//  SettingsStore+Filename.swift
//  Reco
//
//  Created by Diip3sh on 28.09.26.
//

import Foundation

extension SettingsStore {

    /// `<prefix>_<yyyy-MM-dd-HH.mm.ss>.<fileExtension>`, shared by recordings and screenshots
    nonisolated static func filename(prefix: String, fileExtension: String, date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HH.mm.ss"
        return "\(prefix)_\(formatter.string(from: date)).\(fileExtension)"
    }
}
