//
//  OCKAppearanceStyler.swift
//  OCKSample
//
//  Created by ChatGPT on 2026/2/27.
//

import CareKitUI
import UIKit

struct AppearanceStyler: OCKAppearanceStyler {
    #if os(iOS)

    var separatorHeight: CGFloat { 1.0 }

    #endif

    // Implement all protocol properties locally to avoid linking CareKitUI extension defaults.
    var lineWidth1: CGFloat { 1.0 }
    var borderWidth1: CGFloat { 1.0 }
    var borderWidth2: CGFloat { 2.0 }
    var opacity1: CGFloat { 1.0 }

    // Softer, more rounded cards to match the login screen.
    var cornerRadius1: CGFloat { 16 }
    var cornerRadius2: CGFloat { 10 }

    // Light shadow to make cards gently float above the background.
    var shadowOpacity1: Float { 0.12 }
    var shadowRadius1: CGFloat { 6 }
    var shadowOffset1: CGSize { CGSize(width: 0, height: 3) }

}
