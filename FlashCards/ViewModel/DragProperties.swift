//
//  DragProperties.swift
//  FlashCards
//
//  Created by USER on 15/05/25.
//

import SwiftUI
import CoreData

/// I'm going to create a custom drag and drop effect instead of using the native drag and drop feature because it lacks customization
/// options for its preview. Additionally, the observale object contains all of its associated data
class DragProperties: ObservableObject {
    /// Drag Preview Properties
    @Published var show: Bool = false
    @Published var previewImage: UIImage?
    @Published var initialViewLocation: CGPoint = .zero
    @Published var updatedViewLocation: CGPoint = .zero
    /// Gesture Properties
    @Published var offset: CGSize = .zero
    @Published var location: CGPoint = .zero
    /// For Grouping and Section Re-Ordering
    @Published var sourceCard: FlashCard?
    @Published var sourceCategory: Category?
    @Published var destinationCategory: Category?
    @Published var isCardsSwapped: Bool = false
    
    /// Reset's all properties
    func resetAllProperties() {
        self.show = false
        self.previewImage = nil
        self.initialViewLocation = .zero
        self.updatedViewLocation = .zero
        self.offset = .zero
        self.location = .zero
        self.sourceCard = nil
        self.sourceCategory = nil
        self.destinationCategory = nil
        self.isCardsSwapped = false
    }
    
    func changeGroup(_ context: NSManagedObjectContext) {
        guard let sourceCard, let destinationCategory else { return }
        /// Also I wanted the newly added card to the bottom of the category
        sourceCard.order = destinationCategory.nextOrder
        /// Simply change the category and that's it
        sourceCard.category = destinationCategory
        try? context.save()
        resetAllProperties()
    }
    
    func swapCardsInSameGroup(_ destinationCard: FlashCard) {
        guard let sourceCard else { return }
        let sourceIndex = sourceCard.order
        let destinationIndex = destinationCard.order
        
        /// Swapping orders
        sourceCard.order = destinationIndex
        destinationCard.order = sourceIndex
        
        isCardsSwapped = true
    }
}

extension Category {
    var nextOrder: Int32 {
        let allCards = cards?.allObjects as? [FlashCard] ?? []
        let lastOrderValue = allCards.max(by: { $0.order < $1.order })?.order ?? 0
        return lastOrderValue + 1
    }
}
