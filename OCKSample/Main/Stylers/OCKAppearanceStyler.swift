//
//  OCKAppearanceStyler.swift
//  OCKSample
//
//  Created by 赵承麟 on 2026/3/1.
//  Copyright © 2026 Network Reconnaissance Lab. All rights reserved.
//

@preconcurrency import CareKitUI
import UIKit

struct AppearanceStyle: OCKAppearanceStyler {
    #if os(iOS)
    nonisolated var separatorHeight: CGFloat { 1.0 / 3.0 }
    #endif
    nonisolated var lineWidth1: CGFloat { 1.0 }
    nonisolated var borderWidth1: CGFloat { 1.0 }
    nonisolated var borderWidth2: CGFloat { 2.0 }
    nonisolated var opacity1: CGFloat { 1.0 }
    // Softer, more rounded cards to match the login screen.
    nonisolated var cornerRadius1: CGFloat { 16 }
    nonisolated var cornerRadius2: CGFloat { 10 }

    // Light shadow to make cards gently float above the background.
    nonisolated var shadowOpacity1: Float { 0.12 }
    nonisolated var shadowRadius1: CGFloat { 6 }
    nonisolated var shadowOffset1: CGSize { CGSize(width: 0, height: 3) }

}
