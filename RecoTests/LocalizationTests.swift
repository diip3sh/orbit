//
//  LocalizationTests.swift
//  RecoTests
//

import Foundation
import Testing

struct LocalizationTests {

    private var simplifiedChinese: Bundle? {
        Bundle.main.path(forResource: "zh-Hans", ofType: "lproj").flatMap(Bundle.init(path:))
    }

    private func translation(of key: String) -> String? {
        simplifiedChinese?.localizedString(forKey: key, value: nil, table: nil)
    }

    @Test func simplifiedChineseIsBundled() {
        #expect(simplifiedChinese != nil)
    }

    @Test func aTranslatedStringReadsInChinese() {
        #expect(translation(of: "Cancel") == "取消")
        #expect(translation(of: "Library") == "资源库")
    }

    @Test func aFormattedStringKeepsItsPlaceholders() {
        #expect(translation(of: "Clip %@ of %lld") == "第 %1$@ 个片段，共 %2$lld 个")
    }

    @Test func aMissingTranslationFallsBackToTheKey() {
        let key = "A string nobody has translated yet"
        #expect(translation(of: key) == key)
    }

    @Test func permissionPromptsAreTranslated() {
        let strings = simplifiedChinese.flatMap { $0.path(forResource: "InfoPlist", ofType: "strings") }
            .flatMap { NSDictionary(contentsOfFile: $0) as? [String: String] }
        #expect(strings?["NSMicrophoneUsageDescription"]?.contains("麦克风") == true)
    }
}
