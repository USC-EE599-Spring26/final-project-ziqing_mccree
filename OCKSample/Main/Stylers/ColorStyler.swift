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
    var label: UIColor {
        UIColor(Color("UIPurple"))
    }
    /// Accent color used for less prominent text.
    var tertiaryLabel: UIColor {
        UIColor(Color("BrandPurpleLight"))
    }
    /// Global tint color used by CareKit controls.
    var tint: UIColor {
        UIColor(Color("UIBlue"))
    }
    #endif
}
