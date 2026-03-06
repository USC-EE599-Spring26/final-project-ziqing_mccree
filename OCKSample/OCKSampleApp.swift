//
//  OCKSampleApp.swift
//  OCKSample
//
//  Created by Corey Baker on 9/2/22.
//  Copyright © 2022 Network Reconnaissance Lab. All rights reserved.
//

import Foundation
import SwiftUI
import CareKit
import CareKitStore

@main
struct OCKSampleApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.careKitStyle) var style

    // 全局唯一的 store（UI 读写都用它）
    private let store: OCKStore = OCKStore(
        name: isSyncingWithRemote ? Constants.iOSParseCareStoreName : Constants.iOSLocalCareStoreName,
        type: .onDisk()
    )

    var body: some Scene {
        WindowGroup {
            MainView()
                .environment(\.appDelegate, appDelegate)
                .environment(\.careStore, appDelegate.store)   // 关键：注入 store
                .careKitStyle(style)
        }
    }
}
