import SwiftUI
import CoreData

struct CustomDisclosureGroup: View {
    var category: Category

    @Environment(\.managedObjectContext) private var context
    @Binding var selectedCategory: Category?
    @Binding var showingCategorySheet: Bool
    @State private var isExpanded: Bool = true
    @State private var gestureRect: CGRect = .zero
    @EnvironmentObject private var properties: DragProperties

    // Computed filtered flashcards
    private var cards: [FlashCard] {
        let request = NSFetchRequest<FlashCard>(entityName: "FlashCard")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \FlashCard.order, ascending: true)]
        request.predicate = NSPredicate(format: "category == %@", category)

        do {
            return try context.fetch(request)
        } catch {
            print("Failed to fetch flashcards: \(error)")
            return []
        }
    }

    var body: some View {
        let isDropping = gestureRect.contains(properties.location) && properties.sourceCategory != category
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Text(category.title ?? "New Folder")
                Spacer(minLength: 0)
                Menu {
                    Button {
                        selectedCategory = category
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    Button(role: .destructive) {
                        context.delete(category)
                        try? context.save()
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                }
                Image(systemName: "chevron.down")
                    .rotationEffect(.init(degrees: isExpanded ? 0 : 180))
                    .onTapGesture {
                        withAnimation(.snappy) {
                            isExpanded.toggle()
                        }
                    }
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
        .animation(.easeInOut(duration: 0.2)) {
            $0.background(isDropping ? .blue.opacity(0.2) : .gray.opacity(0.1))
        }
        .clipShape(.rect(cornerRadius: 10))
        .contentShape(.rect)
        .onGeometryChange(for: CGRect.self) {
            $0.frame(in: .global)
        } action: { newValue in
            gestureRect = newValue
        }
        .onChange(of: isDropping) { _, new in
            properties.destinationCategory = new ? category : nil
        }
    }

    @ViewBuilder
    private func cardsView() -> some View {
        if cards.isEmpty {
            Text("Ready when you are, add some tasks to this category!")
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
