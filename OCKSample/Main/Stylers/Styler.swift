//
//  Styler.swift
//  OCKSample
//
//  Created by Corey Baker on 10/16/21.
//  Copyright © 2021 Network Reconnaissance Lab. All rights reserved.
//

@preconcurrency import CareKitUI

@MainActor
struct Styler: OCKStyler {
    nonisolated var color: OCKColorStyler {
        ColorStyler()
    }
    nonisolated var dimension: OCKDimensionStyler {
        DimensionStyle()
    }
    nonisolated var animation: OCKAnimationStyler {
        AnimationStyle()
    }
    nonisolated var appearance: OCKAppearanceStyler {
        AppearanceStyle()
    }
}
