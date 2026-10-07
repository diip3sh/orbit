//
//  EditorViewModel+Motion.swift
//  Reco
//
//  Created by Diip3sh on 07.10.26.
//

import Foundation

extension EditorViewModel {

    /// How the camera moves between zooms, for the inspector's Motion tab. Each change is an edit.
    var zoomMotion: ZoomMotion {
        get { project.zoomMotion }
        set { edit("Zoom Motion") { $0.zoomMotion = newValue } }
    }

    /// How much the camera's moves blur, from 0 to 1. Each change is an edit; one slider drag is one step.
    var motionBlur: Double {
        get { project.motionBlur }
        set { edit("Motion Blur", coalescing: true) { $0.motionBlur = newValue } }
    }
}
