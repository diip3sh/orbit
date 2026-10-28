//
//  LibraryHeader.swift
//  Reco
//

import SwiftUI

/// The top of the Library's content panel, in the title bar's row: the section's heading and count, search,
/// Filter and New.
struct LibraryHeader: View {
    @Bindable var viewModel: LibraryViewModel

    /// Whether the search field has the focus, which ⌘F gives it (the system's `.searchable` field did).
    @FocusState private var isSearching: Bool

    var body: some View {
        HStack(spacing: EditorTheme.mediumSpacing) {
            VStack(alignment: .leading, spacing: 1) {
                Text(viewModel.section.heading)
                    .font(.theme(.title3, weight: .semibold))
                    .foregroundStyle(EditorTheme.ink)
                Text("^[\(viewModel.shown.count) item](inflect: true)")
                    .font(.theme(.callout))
                    .foregroundStyle(EditorTheme.dim)
            }
            .lineLimit(1)

            Spacer(minLength: 0)

            LibrarySearchField(text: $viewModel.search, isFocused: $isSearching)
            LibraryFilterMenu(orientation: $viewModel.orientation, sort: $viewModel.sort)
            LibraryNewMenu(actions: viewModel.actions)
        }
        .padding(.leading, EditorTheme.largeSpacing)
        .padding(.trailing, 14)
        .frame(height: 60)
        .background {
            Button("Search by Name") { isSearching = true }
                .keyboardShortcut("f")
                .opacity(0)
                .frame(width: 0, height: 0)
                .accessibilityHidden(true)
        }
    }
}

/// Search by name, in a capsule as wide as the design's.
private struct LibrarySearchField: View {
    @Binding var text: String
    @FocusState.Binding var isFocused: Bool

    var body: some View {
        HStack(spacing: EditorTheme.smallSpacing) {
            Image(systemName: "magnifyingglass")
                .font(.theme(.title3))
                .foregroundStyle(EditorTheme.dim)
                .accessibilityHidden(true)
            TextField("Search by name", text: $text, prompt: Text("Search by name").foregroundStyle(EditorTheme.faint))
                .textFieldStyle(.plain)
                .font(.theme(.body))
                .foregroundStyle(EditorTheme.ink)
                .focused($isFocused)
            if !text.isEmpty {
                Button("Clear Search", systemImage: "xmark.circle.fill") {
                    text = ""
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.plain)
                .foregroundStyle(EditorTheme.faint)
            }
        }
        .padding(.horizontal, 14)
        .frame(width: 260)
        .headerCapsule()
    }
}

/// Filter: the pictures' shape, and the grid's order.
private struct LibraryFilterMenu: View {
    @Binding var orientation: LibraryOrientation?
    @Binding var sort: LibrarySort

    var body: some View {
        Menu {
            Picker("Shape", selection: $orientation) {
                Text("Any Shape").tag(LibraryOrientation?.none)
                ForEach(LibraryOrientation.allCases, id: \.self) { orientation in
                    Label(orientation.title, systemImage: orientation.symbol).tag(Optional(orientation))
                }
            }
            .pickerStyle(.inline)
            Picker("Sort By", selection: $sort) {
                ForEach(LibrarySort.allCases, id: \.self) { sort in
                    Text(sort.title).tag(sort)
                }
            }
            .pickerStyle(.inline)
        } label: {
            // Filled while a shape narrows the grid, so a short grid says why
            HeaderMenuLabel(
                title: "Filter",
                symbol: orientation == nil ? "line.3.horizontal.decrease" : "line.3.horizontal.decrease.circle.fill"
            )
            .foregroundStyle(EditorTheme.ink)
            .padding(.horizontal, 14)
            .headerCapsule()
            .headerMenuAnchor()
        }
        .headerMenuStyle()
        .help("Show one shape, and choose the order")
    }
}

/// New: a screenshot, a screen recording or a web recording.
private struct LibraryNewMenu: View {
    let actions: LibraryViewModel.Actions

    var body: some View {
        Menu {
            Section("Screenshot") {
                Button("Capture Area", systemImage: "rectangle.dashed", action: actions.captureArea)
                Button("Capture Window", systemImage: "macwindow", action: actions.captureWindow)
                Button("Capture Screen", systemImage: "display", action: actions.captureScreen)
            }
            Section("Recording") {
                Button("Record Area…", systemImage: "rectangle.dashed.badge.record", action: actions.recordArea)
                Button("Record Window or Display…", systemImage: "macwindow", action: actions.recordWindowOrDisplay)
            }
            Section("Web") {
                Button("New Web Recording…", systemImage: "globe", action: actions.newWebRecording)
            }
        } label: {
            HeaderMenuLabel(title: "New", symbol: "plus", isProminent: true)
                .foregroundStyle(EditorTheme.onAccent)
                .padding(.horizontal, EditorTheme.spacing)
                .headerProminentCapsule()
                .headerMenuAnchor()
        }
        .headerMenuStyle()
        .help("Take a screenshot or start a recording")
    }
}
