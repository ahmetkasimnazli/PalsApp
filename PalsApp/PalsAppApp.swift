//
//  PalsAppApp.swift
//  PalsApp
//
//  Created by Ahmet Kasım Nazlı on 18.11.2026.
//

import SwiftUI

@main
struct PalsAppApp: App {
    init() {
        PalsFont.register()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
