//
//  WebAddressBar.swift
//  Reco
//

import SwiftUI

/// The page's address on a capsule, its host in ink and the rest dim until clicked, when it's a field: ⏎ loads
/// what's typed. Reload on the left, the viewport's menu on the right.
struct WebAddressBar: View {
    @Bindable var viewModel: WebRecordingViewModel

    @FocusState private var isEditing: Bool

    var body: some View {
        HStack(spacing: EditorTheme.mediumSpacing) {
            Button("Reload", systemImage: "arrow.clockwise") {
                viewModel.reload()
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.plain)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(EditorTheme.dim)
            .help("Load the script's page again")
            .disabled(viewModel.script.url == nil)

            ZStack(alignment: .leading) {
                TextField("Address", text: $viewModel.address, prompt: Text("Enter a web address"))
                    .textFieldStyle(.plain)
                    .font(.theme())
                    .focused($isEditing)
                    .onSubmit {
                        viewModel.commitAddress()
                        isEditing = false
                    }
                    .opacity(shownURL == nil ? 1 : 0)
                if let url = shownURL {
                    Self.formatted(url)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(.rect)
                        .onTapGesture { isEditing = true }
                        .pointerStyle(.horizontalText)
                }
            }

            viewportMenu
        }
        // The script's page stays put while it renders
        .disabled(!viewModel.isEditable)
        .padding(.leading, EditorTheme.spacing)
        .padding(.trailing, EditorTheme.tightSpacing)
        .frame(height: 36)
        .webField()
    }

    /// The script's page, shown formatted while the field isn't being typed in and holds that page.
    private var shownURL: URL? {
        guard !isEditing, let url = viewModel.script.url, WebScript.url(from: viewModel.address) == url else { return nil }
        return url
    }

    /// The viewport's name and size, choosing another.
    private var viewportMenu: some View {
        let size = viewModel.script.viewport
        return Menu {
            Picker("Viewport", selection: $viewModel.viewport) {
                ForEach(WebScript.Viewport.allCases, id: \.self) { viewport in
                    Text("\(Text(viewport.title)) · \(viewport.size.pixels)")
                        .tag(Optional(viewport))
                }
            }
            .pickerStyle(.inline)
        } label: {
            HStack(spacing: EditorTheme.smallSpacing) {
                Text(viewModel.viewport?.title ?? "Custom")
                    .font(.theme(.callout, weight: .medium))
                    .foregroundStyle(EditorTheme.ink)
                Text(size.pixels)
                    .font(.theme(.subheadline, .mono))
                    .foregroundStyle(EditorTheme.dim)
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(EditorTheme.dim)
            }
            .padding(.leading, EditorTheme.mediumSpacing)
            .padding(.trailing, EditorTheme.smallSpacing)
            .frame(height: 28)
            .background(EditorTheme.ink.opacity(0.08), in: .capsule)
            .contentShape(.capsule)
            .headerMenuAnchor()
        }
        .menuStyle(.button)
        .menuIndicator(.hidden)
        .buttonStyle(.plain)
        .fixedSize()
        .help("The page's size in the take")
    }

    /// "apple.com/macbook-pro": the host without `www.`, in ink, then the rest dim.
    static func formatted(_ url: URL) -> Text {
        var host = url.host(percentEncoded: false) ?? ""
        if host.hasPrefix("www.") {
            host.removeFirst(4)
        }
        if let port = url.port {
            host += ":\(port)"
        }
        var rest = url.path(percentEncoded: false)
        if rest.hasSuffix("/") {
            rest.removeLast()
        }
        if let query = url.query(percentEncoded: false) {
            rest += "?\(query)"
        }
        return Text("\(Text(host).font(.theme(weight: .medium)).foregroundStyle(EditorTheme.ink))\(Text(rest).font(.theme()).foregroundStyle(EditorTheme.dim))")
    }
}

extension WebScript.Viewport {

    var title: LocalizedStringKey {
        switch self {
        case .desktop: "Desktop"
        case .laptop: "Laptop"
        case .tablet: "Tablet"
        case .phone: "Phone"
        }
    }
}
