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
        .sheet(item: $selectedCategory) { item in
            AddEditCategoryView(
                category: item,
                context: context
            ) {
                // completion
                selectedCategory = nil
            }
        }
        .sheet(isPresented: $showingCategorySheet) {
            AddEditCategoryView(
                category: selectedCategory,
                context: context
            ) {
                // completion
                showingCategorySheet = false
                selectedCategory = nil
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
  
  // Alert state
  @State private var showAlert = false
  @State private var alertMessage = ""

  init(category: Category?, context: NSManagedObjectContext, onComplete: @escaping ()->Void) {
    self.category = category
    self.context = context
    self.onComplete = onComplete
  }

  var body: some View {
    NavigationStack {
      Form {
        Section("Category") {
          TextField("Title", text: $title)
        }
        Section("Action Cards") {
          ForEach(cardTitles.indices, id: \.self) { idx in
            HStack {
              TextField("Go for a walk", text: $cardTitles[idx])
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
            .disabled(!canSave)
        }
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
        }
      }
      .alert(alertMessage, isPresented: $showAlert) {
        Button("OK", role: .cancel) {}
      }
      .onAppear {
        if let cat = category {
          title = cat.title ?? ""
          let existing = (cat.cards as? Set<FlashCard>)?
            .sorted { $0.order < $1.order } ?? []
          cardTitles = existing.map { $0.title ?? "" }
        }
      }
    }
  }
  
  private var canSave: Bool {
    !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }
  
  private func saveAndDismiss() {
    let trimmedCategoryTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
    
    // Validate category title uniqueness
    let fetchRequest = NSFetchRequest<Category>(entityName: "Category")
    fetchRequest.predicate = NSPredicate(format: "title == %@", trimmedCategoryTitle)
    do {
      let existingCategories = try context.fetch(fetchRequest)
      // If new category, any existing with same title is error
      // If editing, exclude self from duplicates
      if category == nil {
        if !existingCategories.isEmpty {
          alertMessage = "Category title must be unique."
          showAlert = true
          return
        }
      } else {
        if existingCategories.contains(where: { $0 != category }) {
          alertMessage = "Category title must be unique."
          showAlert = true
          return
        }
      }
    } catch {
      // Handle fetch error if needed
    }
    
    // Validate unique card titles (trimmed, non-empty)
    let trimmedCards = cardTitles.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    let uniqueCards = Set(trimmedCards)
    if uniqueCards.count != trimmedCards.count {
      alertMessage = "Card titles must be unique."
      showAlert = true
      return
    }
    
    // All validation passed, proceed to save
    
    let cat = category ?? Category(context: context)
    cat.title = trimmedCategoryTitle
    if category == nil { cat.dateCreated = Date() }
    
    // Map old cards' isDone state
    var isDoneMap: [String: Bool] = [:]
    if let existing = cat.cards as? Set<FlashCard> {
      for card in existing {
        if let title = card.title {
          isDoneMap[title] = card.isDone
        }
        context.delete(card)
      }
    }
    
    // Recreate cards preserving isDone state where possible
    for (i, t) in cardTitles.enumerated() where !t.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      let card = FlashCard(context: context)
      card.title = t.trimmingCharacters(in: .whitespacesAndNewlines)
      card.order = Int32(i)
      card.category = cat
      card.isDone = isDoneMap[t] ?? false
    }
    
    do {
      try context.save()
      onComplete()
    } catch {
      alertMessage = "Failed to save: \(error.localizedDescription)"
      showAlert = true
    }
  }
}
