//
//  Fixture.swift
//  RecoTests
//
//  Created by Diip3sh on 26.09.26.
//

import Foundation
import Testing

/// Reads the JSON files in `Fixtures`, which are copied into the test bundle.
enum Fixture {

    static func data(_ name: String) throws -> Data {
        let url = try #require(Bundle(for: BundleToken.self).url(forResource: name, withExtension: "json"))
        return try Data(contentsOf: url)
    }

    private final class BundleToken {}
}
