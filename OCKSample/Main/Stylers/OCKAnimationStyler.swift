//
//  OCKAnimationStyler.swift
//  OCKSample
//
//  Created by ChatGPT on 2026/2/27.
//

import CareKitUI
import UIKit

struct AnimationStyler: OCKAnimationStyler {

    // Faster, more responsive state change animations for cards and buttons.
    var stateChangeDuration: TimeInterval { 0.25 }
    var stateChangeDelay: TimeInterval { 0 }

    // Slight spring effect when toggling completion to make it feel more playful.
    var stateChangeSpringDamping: CGFloat { 0.8 }
    var stateChangeSpringInitialVelocity: CGFloat { 0.5 }

    // Subtle highlight flash when a card is tapped.
    var selectionFlashDuration: TimeInterval { 0.15 }
}
