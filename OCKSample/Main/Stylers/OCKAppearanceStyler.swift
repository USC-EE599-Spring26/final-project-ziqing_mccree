//
//  AppearanceStyler.swift
//  OCKSample
//
//  Created by ChatGPT on 2026/2/27.
//

import CareKitUI
import UIKit

struct AppearanceStyler: OCKAppearanceStyler {

    // Softer, more rounded cards to match the login screen.
    var cornerRadius1: CGFloat { 16 }
    var cornerRadius2: CGFloat { 10 }

    // Light shadow to make cards gently float above the background.
    var shadowOpacity1: Float { 0.12 }
    var shadowRadius1: CGFloat { 6 }
    var shadowOffset1: CGSize { CGSize(width: 0, height: 3) }

    // Slightly thicker separators using the brand blue color.
    var separatorThickness1: CGFloat { 1.0 / UIScreen.main.scale }
    var separatorColor1: UIColor {
        UIColor(Color("BrandBlueLight")).withAlphaComponent(0.5)
    }
}

