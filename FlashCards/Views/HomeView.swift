//
//  HomeView.swift
//  FlashCards
//
//  Created by USER on 15/05/25.
//

import SwiftUI
import CoreData

struct HomeView: View {
    @FetchRequest(
        entity: Category.entity(),
        sortDescriptors: [.init(keyPath: \Category.dateCreated, ascending: false)]
    ) private var categories: FetchedResults<Category>
    @Environment(\.managedObjectContext) private var context
    @EnvironmentObject private var properties: DragProperties

    /// Scroll properties
    @State private var scrollPosition: ScrollPosition = .init()
    @State private var currentScrollOffset: CGFloat = .zero
    @State private var dragScrollOffset: CGFloat = .zero
    @GestureState private var isActive: Bool = false
    
    @State private var showingCategorySheet = false
    @State private var selectedCategory: Category? = nil
    
    var body: some View {
        ScrollView(.vertical) {
            VStack(spacing: 15) {
                ForEach(categories) { category in
                    CustomDisclosureGroup(category: category, selectedCategory: $selectedCategory, showingCategorySheet: $showingCategorySheet)
                }
            }
            .padding(15)
        }
        .sheet(isPresented: $showingCategorySheet) {
            AddEditCategoryView(
                category: selectedCategory,
                context: context
            ) {
                // completion
                showingCategorySheet = false
            }
        }
        .overlay(
            // Floating + button instead of toolbar, or you can keep toolbar
            VStack {
                Spacer()
                HStack { Spacer()
                    Button {
                        selectedCategory = nil
                        showingCategorySheet = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.largeTitle)
                            .foregroundColor(.blue)
                    }
                    .padding()
                }
            }
        )
        .scrollPosition($scrollPosition)
        .onScrollGeometryChange(for: CGFloat.self, of: { $0.contentOffset.y + $0.contentInsets.top }, action: { old, new in
            currentScrollOffset = new
        })
        .allowsHitTesting(!properties.show)
        .contentShape(.rect)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .global)
                .updating($isActive, body: {_, out, _ in
                    out = true
                })
                .onChanged({ value in
                    if dragScrollOffset == 0 {
                        dragScrollOffset = currentScrollOffset
                    }
                    scrollPosition.scrollTo(y: dragScrollOffset + (-value.translation.height))
                }),
            isEnabled: properties.show
        )
        .onChange(of: isActive) {
            old, new in
            if !new {
                dragScrollOffset = 0
            }
        }
    }
}

#Preview {
    ContentView()
    /// Preview Core data for testing
        .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
}

// MARK: — AddEditCategoryView.swift

struct AddEditCategoryView: View {
  let category: Category?
  let context: NSManagedObjectContext
  let onComplete: ()->Void

  // Local editable state
  @State private var title: String = ""
  @State private var cardTitles: [String] = []

  @Environment(\.dismiss) private var dismiss

  init(category: Category?, context: NSManagedObjectContext, onComplete: @escaping ()->Void) {
    self.category = category
    self.context = context
    self.onComplete = onComplete
    // _title and _cardTitles will be set in .onAppear
  }

  var body: some View {
    NavigationStack {
      Form {
        Section("Category") {
          TextField("Title", text: $title)
        }
        Section("Cards") {
          ForEach(cardTitles.indices, id: \.self) { idx in
            HStack {
              TextField("Card \(idx+1)", text: $cardTitles[idx])
              Button(role: .destructive) {
                cardTitles.remove(at: idx)
              } label: {
                Image(systemName: "trash")
              }
            }
          }
          Button {
            cardTitles.append("")
          } label: {
            Label("Add Card", systemImage: "plus")
          }
        }
      }
      .navigationTitle(category == nil ? "New Category" : "Edit Category")
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("Save") { saveAndDismiss() }
            .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
        }
      }
      .onAppear {
        if let cat = category {
          title = cat.title ?? ""
          // load existing cards in order
          let existing = (cat.cards as? Set<FlashCard>)?
            .sorted { ($0.order) < ($1.order) } ?? []
          cardTitles = existing.map { $0.title ?? "" }
        }
      }
    }
  }

    private func saveAndDismiss() {
        let cat = category ?? Category(context: context)
        cat.title = title
        if category == nil { cat.dateCreated = Date() }

        // Create a map from old card titles to their isDone state
        var isDoneMap: [String: Bool] = [:]
        if let existing = cat.cards as? Set<FlashCard> {
            for card in existing {
                if let title = card.title {
                    isDoneMap[title] = card.isDone
                }
                context.delete(card)  // Delete old card
            }
        }

        // Recreate cards with new titles, order, and preserve isDone if possible
        for (i, t) in cardTitles.enumerated() where !t.isEmpty {
            let card = FlashCard(context: context)
            card.title = t
            card.order = Int32(i)
            card.category = cat
            card.isDone = isDoneMap[t] ?? false  // Preserve existing isDone or default false
        }

        try? context.save()
        onComplete()
    }

}
