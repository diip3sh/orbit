//
//  CameraInspectorSection.swift
//  Reco
//

import SwiftUI

/// The Camera tab: the footage, and how its bubble looks once there is some.
struct CameraInspectorSection: View {
    @Bindable var viewModel: EditorViewModel

    var body: some View {
        CameraFootageCard(viewModel: viewModel)
        if let footage = viewModel.source?.camera {
            CameraStyleCard(viewModel: viewModel, footage: footage)
        }
    }
}
