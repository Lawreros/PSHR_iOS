//
//  PSHR_iOSApp.swift
//  PSHR_iOS
//
//  Created by Ross on 11/5/22.
//

import SwiftUI

@main
struct PSHR_iOSApp: App {
    
    @StateObject var bleSdkManager = PolarBleSdkManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView(bleSdkManager: bleSdkManager)
        }
    }
}
