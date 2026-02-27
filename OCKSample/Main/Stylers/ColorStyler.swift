//
//  ColorStyler.swift
//  OCKSample
//
//  Created by Corey Baker on 10/16/21.
//  Copyright © 2021 Network Reconnaissance Lab. All rights reserved.
//

import CareKitUI
import SwiftUI
import UIKit

struct ColorStyler: OCKColorStyler {
    #if os(iOS) || os(visionOS)
    /// Primary text color for labels.
    var label: UIColor {
        UIColor(Color("BrandPurpleLight"))
    }

    /// Accent color used for less prominent text.
    var tertiaryLabel: UIColor {
        UIColor(Color("BrandBlueLight"))
    }

    /// Global tint color used by CareKit controls.
    var tint: UIColor {
        UIColor(Color("BrandPurpleLight"))
    }

    /// Background for grouped card-style views.
    var customGroupedBackground: UIColor {
        UIColor.systemBackground.withAlphaComponent(0.9)
    }

    /// Color for separators between items.
    var separator: UIColor {
        UIColor(Color("BrandBlueLight")).withAlphaComponent(0.4)
    }

    #endif
}
