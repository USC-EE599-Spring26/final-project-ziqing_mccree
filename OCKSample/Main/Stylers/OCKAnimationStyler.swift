//
//  AnimationStyler.swift.swift
//  OCKSample
//
//  Created by 赵承麟 on 2026/3/1.
//  Copyright © 2026 Network Reconnaissance Lab. All rights reserved.
//

@preconcurrency import CareKitUI
import UIKit

struct AnimationStyle: OCKAnimationStyler {
    #if os(iOS)
    nonisolated var separatorHeight: CGFloat { 1.0 / 3.0 }
    #endif
    // Faster, more responsive state change animations for cards and buttons.
    nonisolated var stateChangeDuration: TimeInterval { 0.25 }
    nonisolated var stateChangeDelay: TimeInterval { 0 }

    // Slight spring effect when toggling completion to make it feel more playful.
    nonisolated var stateChangeSpringDamping: CGFloat { 0.8 }
    nonisolated var stateChangeSpringInitialVelocity: CGFloat { 0.5 }

    // Subtle highlight flash when a card is tapped.
    nonisolated var selectionFlashDuration: TimeInterval { 0.15 }
}
