//
//  CardView.swift
//  FlashCards
//
//  Created by USER on 15/05/25.
//

import SwiftUI

struct FlashCardView: View {
    @ObservedObject var card: FlashCard
    var category: Category
    @EnvironmentObject private var properties: DragProperties
    @Environment(\.managedObjectContext) private var context
    /// View Properties
    @GestureState private var isActive: Bool = false
    /// Let's give some little haptics feedback when the gesture becomes active
    @State private var haptics: Bool = false
    var body: some View {
        GeometryReader {
            let rect = $0.frame(in: .global)
            let isSwappingInSameGroup = rect.contains(properties.location) && properties.sourceCard != card && properties.destinationCategory == nil
            HStack {
                Button(action: {
                    card.isDone.toggle()
                    do {
                        try context.save()
                    } catch {
                        print("Failed to save context: \(error)")
                    }
                }){
                    Image(systemName: card.isDone ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(card.isDone ? .green : .gray)
                }
                .buttonStyle(.plain)
                
                Text(card.title ?? "")
                    .padding(.horizontal, 15)
                    .frame(width: rect.width, height: rect.height, alignment: .leading)
                    .background(Color("Background"), in: .rect(cornerRadius: 10))
                    .gesture(customGesture(rect: rect))
                    .onChange(of: isSwappingInSameGroup) { oldValue, newValue in
                        if newValue {
                            properties.swapCardsInSameGroup(card)
                        }
                    }
            }
        }
        .frame(height: 60)
        /// Hiding the active dragging view
        .opacity(properties.sourceCard == card ? 0 : 1)
        .onChange(of: isActive) { oldValue, newValue in
            if newValue {
                haptics.toggle()
            } else {
                handleGestureEnd()
            }
        }
        /// Once the gesture activates after a successful long press, we can immediately create a preview image of dragging view. We can then display this preview image on top of the root view, effectively creating the illusion that view is currently being dragged
        .sensoryFeedback(.impact, trigger: haptics)
    }
    private func customGesture(rect: CGRect) -> some Gesture {
        LongPressGesture(minimumDuration: 0.3)
            .sequenced(before: DragGesture(coordinateSpace: .global))
            .updating($isActive, body: {_, out, _ in
                out = true
            })
        .onChanged { value in
            /// This means that the long-press gesture has been finished successfully and drag gesture has been initiated
            if case .second(_, let gesture) = value {
                handleGestureChange(gesture, rect: rect)
            }
        }
    }
    private func handleGestureChange(_ gesture: DragGesture.Value?, rect: CGRect) {
        /// Step 1: Let's create a preview image of the dragging view
        if properties.previewImage == nil {
            properties.show = true
            properties.previewImage = createPreviewImage(rect)
            /// Storing source properties
            properties.sourceCard = card
            properties.sourceCategory = category
            properties.initialViewLocation = rect.origin
        }
        guard let gesture else { return }
        /// Updating gesture values
        properties.offset = gesture.translation
        properties.location = gesture.location
        properties.updatedViewLocation = rect.origin
    }
    private func createPreviewImage(_ rect: CGRect) -> UIImage? {
        let view = HStack {
            Text(card.title ?? "")
                .padding(.horizontal, 15)
                .frame(width: rect.width, height: rect.height, alignment: .leading)
                .background(Color("Background"), in: .rect(cornerRadius: 10))
                .foregroundColor(.white)
        }
        let renderer = ImageRenderer(content: view)
        renderer.scale = UIScreen.main.scale
        return renderer.uiImage
    }
    private func handleGestureEnd() {
        withAnimation(.easeInOut(duration: 0.25), completionCriteria: .logicallyComplete) {
            if properties.destinationCategory != nil {
                properties.changeGroup(context)
            } else {
                /// Updating view location if there is any change
                if properties.updatedViewLocation != .zero {
                    properties.initialViewLocation = properties.updatedViewLocation
                }
                properties.offset = .zero
            }
        } completion: {
            if properties.isCardsSwapped {
                try? context.save()
            }
            properties.resetAllProperties()
        }
    }
}

#Preview {
    ContentView()
    /// Preview Core data for testing
        .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
}
