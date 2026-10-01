//
//  AgentModelCatalogTests.swift
//  RecoTests
//

import Testing
@testable import Reco

struct AgentModelCatalogTests {

    @Test func everyAgentWithAChoiceListsEachModelOnce() {
        for kind in AgentKind.allCases {
            let models = AgentModelCatalog.models(for: kind)
            #expect(Set(models).count == models.count)
            #expect(!models.contains(""))
        }
        for kind in [AgentKind.claudeCode, .codex, .gemini, .grok] {
            #expect(!AgentModelCatalog.models(for: kind).isEmpty)
        }
    }

    @Test func openCodeAndCursorOfferOnlyTheirDefault() {
        #expect(AgentModelCatalog.models(for: .openCode).isEmpty)
        #expect(AgentModelCatalog.models(for: .cursor).isEmpty)
    }
}
