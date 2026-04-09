//
//  Styler.swift
//  OCKSample
//
//  Created by Corey Baker on 10/16/21.
//  Copyright © 2021 Network Reconnaissance Lab. All rights reserved.
//

import CareKitUI

struct Styler: OCKStyler {
    var color: OCKColorStyler {
        ColorStyler()
    }
    var dimension: OCKDimensionStyler {
        DimensionStyle()
    }
    var animation: OCKAnimationStyler {
        OCKAnimationStyle()
    }
    var appearance: OCKAppearanceStyler {
        OCKAppearanceStyle()
    }
}
