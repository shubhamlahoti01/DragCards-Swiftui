//
//  ContentView.swift
//  FlashCards
//
//  Created by USER on 14/05/25.
//

import SwiftUI
import CoreData

struct ContentView: View {
    @StateObject private var dragProperties: DragProperties = .init()
    var body: some View {
        NavigationStack {
            HomeView()
                .navigationTitle("TODO")
                .navigationBarTitleDisplayMode(.inline)
        }
        /// Always the dark mode
        .preferredColorScheme(.dark)
        .overlay(alignment: .topLeading) {
            if let previewImage = dragProperties.previewImage, dragProperties.show {
                Image(uiImage: previewImage)
                    .opacity(0.8)
                    .offset(x: dragProperties.initialViewLocation.x, y: dragProperties.initialViewLocation.y)
                    .offset(dragProperties.offset)
                    .ignoresSafeArea()
            }
        }
        .environmentObject(dragProperties)
    }
}


#Preview {
    ContentView()
}
