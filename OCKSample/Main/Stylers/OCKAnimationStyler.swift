//
//  AnimationStyler.swift.swift
//  OCKSample
//
//  Created by 赵承麟 on 2026/3/1.
//  Copyright © 2026 Network Reconnaissance Lab. All rights reserved.
//

import CareKitUI
import UIKit

struct AnimationStyle: OCKAnimationStyler {
    #if os(iOS)

    var separatorHeight: CGFloat { 1.0 }

    #endif
    // Faster, more responsive state change animations for cards and buttons.
    var stateChangeDuration: TimeInterval { 0.25 }
    var stateChangeDelay: TimeInterval { 0 }

    // Slight spring effect when toggling completion to make it feel more playful.
    var stateChangeSpringDamping: CGFloat { 0.8 }
    var stateChangeSpringInitialVelocity: CGFloat { 0.5 }

    // Subtle highlight flash when a card is tapped.
    var selectionFlashDuration: TimeInterval { 0.15 }
}
