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
        // Standard navigation bars, set in the app's typeface.
        let bar = UINavigationBar.appearance()
        bar.largeTitleTextAttributes = [.font: PalsFont.uiFont(size: 34, weight: .black, relativeTo: .largeTitle)]
        bar.titleTextAttributes = [.font: PalsFont.uiFont(size: 17, weight: .bold, relativeTo: .headline)]
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
