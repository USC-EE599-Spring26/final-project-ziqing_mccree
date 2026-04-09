//
//  OCKDimensionStyle.swift
//  OCKSample
//
//  Created by 赵承麟 on 2026/3/1.
//  Copyright © 2026 Network Reconnaissance Lab. All rights reserved.
//

@preconcurrency import CareKitUI
import UIKit

struct DimensionStyle: OCKDimensionStyler {
    #if os(iOS)
    nonisolated var separatorHeight: CGFloat { 1.0 / 3.0 }
    #endif

    nonisolated var lineWidth1: CGFloat { 20 }
    nonisolated var stackSpacing1: CGFloat { 8 }

    nonisolated var imageHeight2: CGFloat { 40 }
    nonisolated var imageHeight1: CGFloat { 350 }

    nonisolated var pointSize3: CGFloat { 50 }
    nonisolated var pointSize2: CGFloat { 14 }
    nonisolated var pointSize1: CGFloat { 17 }

    nonisolated var symbolPointSize5: CGFloat { 8 }
    nonisolated var symbolPointSize4: CGFloat { 12 }
    nonisolated var symbolPointSize3: CGFloat { 30 }
    nonisolated var symbolPointSize2: CGFloat { 20 }
    nonisolated var symbolPointSize1: CGFloat { 30 }
}
