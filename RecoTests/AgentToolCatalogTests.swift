//
//  AgentToolCatalogTests.swift
//  RecoTests
//

import Foundation
import MCP
import Testing
@testable import Reco

@MainActor
struct AgentToolCatalogTests {

    @Test func theCatalogHasItsToolsWithUniqueNames() {
        let names = AgentToolCatalog.tools.map(\.name)

        #expect(names == ["inspect_page", "record_page", "render_status", "export_recording", "edit_motion", "capture_ui", "preview_motion"])
        #expect(Set(names).count == names.count)
    }

    @Test func everySchemaIsAnObjectSchema() throws {
        for definition in AgentToolCatalog.tools {
            let schema = try JSONDecoder().decode(Value.self, from: Data(definition.schema.utf8))
            #expect(schema.objectValue?["type"]?.stringValue == "object", "\(definition.name)")
            #expect(schema.objectValue?["properties"]?.objectValue != nil, "\(definition.name)")
            #expect(schema.objectValue?["required"]?.arrayValue?.isEmpty == false, "\(definition.name)")
        }
    }

    @Test func theServerOffersEveryDefinitionWithItsSchema() {
        let tools = AgentBridgeServer.mcpTools

        #expect(tools.map(\.name) == AgentToolCatalog.tools.map(\.name))
        #expect(tools.allSatisfy { $0.inputSchema.objectValue?["type"]?.stringValue == "object" })
        #expect(tools.allSatisfy { $0.description?.isEmpty == false })
    }

    @Test func requestsAsAnAgentWritesThemDecode() throws {
        let record = Data("""
            {"url":"apple.com","viewport":"laptop","scale":1,"duration":9.5,"steps":[{"action":"click","selector":"#buy","start":1},\
            {"action":"scroll","y":800,"duration":2}]}
            """.utf8)
        let inspect = Data(#"{"url":"apple.com","viewport":"phone"}"#.utf8)

        let recording = try JSONDecoder().decode(RecordPageRequest.self, from: record)
        let inspection = try JSONDecoder().decode(InspectPageRequest.self, from: inspect)

        #expect(recording.url == "apple.com")
        #expect(recording.steps.map(\.action) == ["click", "scroll"])
        #expect(recording.steps[1].offset == 800)
        #expect(recording.steps[0].start == 1)
        #expect(recording.duration == 9.5)
        let script = try inspection.validated()
        #expect(script.url?.absoluteString == "https://apple.com")
        #expect(script.viewport == WebScript.Viewport.phone.size)
    }

    @Test func aRenderStatusIsWrittenInTheSchemasNames() throws {
        let status = RenderStatus(renderID: "abc", status: .done, progress: 1, movie: "/m.mov", telemetry: "/m.telemetry.json", unmatchedSelectors: ["#x"])
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys

        let json = try #require(String(data: encoder.encode(status), encoding: .utf8))

        #expect(json == ##"{"movie":"\/m.mov","progress":1,"render_id":"abc","status":"done","telemetry":"\/m.telemetry.json","unmatched_selectors":["#x"]}"##)
    }
}
