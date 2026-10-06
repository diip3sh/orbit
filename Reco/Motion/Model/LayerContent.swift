//
//  LayerContent.swift
//  Reco
//

import CoreGraphics

/// What a layer shows. Coded as an object with one key naming the kind:
/// `{"text": {...}}`, `{"image": {...}}`, `{"shape": {...}}` or `{"group": [layers]}`.
nonisolated enum LayerContent: Equatable, Sendable {
    case text(TextContent)
    case image(ImageContent)
    case shape(ShapeContent)

    /// Layers moved together: their transforms are inside the group's, their opacity multiplied by it.
    case group([MotionLayer])
}

// MARK: - Codable

nonisolated extension LayerContent: Codable {

    private enum CodingKeys: String, CodingKey {
        case text, image, shape, group
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        guard container.allKeys.count == 1, let key = container.allKeys.first else {
            throw DecodingError.dataCorrupted(DecodingError.Context(
                codingPath: decoder.codingPath, debugDescription: "Content names one kind: text, image, shape or group"
            ))
        }
        switch key {
        case .text: self = .text(try container.decode(TextContent.self, forKey: key))
        case .image: self = .image(try container.decode(ImageContent.self, forKey: key))
        case .shape: self = .shape(try container.decode(ShapeContent.self, forKey: key))
        case .group: self = .group(try container.decode([MotionLayer].self, forKey: key))
        }
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .text(let text): try container.encode(text, forKey: .text)
        case .image(let image): try container.encode(image, forKey: .image)
        case .shape(let shape): try container.encode(shape, forKey: .shape)
        case .group(let layers): try container.encode(layers, forKey: .group)
        }
    }
}
