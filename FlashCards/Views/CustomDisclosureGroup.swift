//
//  CategoryDisclosureGroup.swift
//  FlashCards
//
//  Created by USER on 15/05/25.
//

import SwiftUI

struct CustomDisclosureGroup: View {
    var category: Category
    init(category: Category) {
        self.category = category
        let descriptors = [NSSortDescriptor(keyPath: \FlashCard.order, ascending: true)]
        let predicate = NSPredicate(format: "category == %@", category)
        _cards = .init(
            entity: FlashCard.entity(),
            sortDescriptors: descriptors,
            predicate: predicate,
            animation: .easeInOut(duration: 0.15)
        )
    }
    @FetchRequest private var cards: FetchedResults<FlashCard>
    
    /// View Properties
    /// all the categories to be expanded (But can change this behaviour)
    @State private var isExpanded: Bool = true
    @State private var gestureRect: CGRect = .zero
    @EnvironmentObject private var properties: DragProperties
    
    var body: some View {
        let isDropping = gestureRect.contains(properties.location) && properties.sourceCategory != category
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Text(category.title ?? "New Folder")
                Spacer(minLength: 0)
                Image(systemName: "chevron.down")
                    .rotationEffect(.init(degrees: isExpanded ? 0 : 180))
            }
            .font(.callout)
            .fontWeight(.semibold)
            .foregroundStyle(.blue)
            
            if isExpanded {
                cardsView()
                    .transition(.blurReplace)
            }
        }
        .padding(15)
        .padding(.vertical, isExpanded ? 0 : 5)
        /// Let's add some little animation
        .animation(.easeInOut(duration: 0.2)) {
            $0
                .background(isDropping ? .blue.opacity(0.2) : .gray.opacity(0.1))
        }
        .clipShape(.rect(cornerRadius: 10))
        .contentShape(.rect)
        .onTapGesture {
            withAnimation(.snappy) {
                isExpanded.toggle()
            }
        }
        .onGeometryChange(for: CGRect.self) {
            $0.frame(in: .global)
        } action: { newValue in
            gestureRect = newValue
        }
        .onChange(of: isDropping, {
            old, new in
            properties.destinationCategory = new ? category : nil
        })

    }
    
    @ViewBuilder
    private func cardsView() -> some View {
        if cards.isEmpty {
            Text("No Flash cards have been\nadded to this folder yet.")
                .font(.callout)
                .multilineTextAlignment(.center)
                .foregroundStyle(.gray)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
        } else {
            ForEach(cards) { card in
                FlashCardView(card: card, category: category)
            }
        }
    }
}

#Preview {
    ContentView()
    /// Preview Core data for testing
        .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
}
