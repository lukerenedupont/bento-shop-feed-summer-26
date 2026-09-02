import SwiftUI

struct GiftGuideBrief: Codable, Equatable {
    var recipientName: String
    var relationship: String
    var occasion: String
    var interests: [GiftGuideInterest]

    static let leon = GiftGuideBrief(
        recipientName: "Leon",
        relationship: "Son",
        occasion: "Just because",
        interests: [.outdoors, .games, .making]
    )
}

enum GiftGuideInterest: String, Codable, CaseIterable, Identifiable {
    case outdoors
    case games
    case making
    case sports
    case music
    case style
    case food
    case books
    case animals
    case travel
    case home
    case surprises

    var id: String { rawValue }
    var title: String {
        switch self {
        case .outdoors: "The outdoors"
        case .games: "Games & play"
        case .making: "Building things"
        case .sports: "Sports & gear"
        case .music: "Music"
        case .style: "Style"
        case .food: "Foodie finds"
        case .books: "Books & stories"
        case .animals: "Animals"
        case .travel: "Travel"
        case .home: "The perfect home"
        case .surprises: "Unexpected finds"
        }
    }
    var symbol: String {
        switch self {
        case .outdoors: "tree"
        case .games: "gamecontroller"
        case .making: "hammer"
        case .sports: "basketball"
        case .music: "music.note"
        case .style: "tshirt"
        case .food: "fork.knife"
        case .books: "book.closed"
        case .animals: "pawprint"
        case .travel: "airplane"
        case .home: "house"
        case .surprises: "gift"
        }
    }
}

@Observable
@MainActor
final class GiftGuideBriefStore {
    static let shared = GiftGuideBriefStore()
    private static let defaultsKey = "latestGiftGuideBrief"

    private(set) var current: GiftGuideBrief
    private(set) var hasCreatedGuide: Bool

    private init() {
        if let data = UserDefaults.standard.data(forKey: Self.defaultsKey),
           let brief = try? JSONDecoder().decode(GiftGuideBrief.self, from: data) {
            current = brief
            hasCreatedGuide = true
        } else {
            current = .leon
            hasCreatedGuide = false
        }
    }

    func save(_ brief: GiftGuideBrief) {
        current = brief
        hasCreatedGuide = true
        if let data = try? JSONEncoder().encode(brief) {
            UserDefaults.standard.set(data, forKey: Self.defaultsKey)
        }
    }
}

struct GiftGuideCreationFlow: View {
    let onComplete: (GiftGuideBrief) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var recipient = "Leon"
    @State private var relationship = "Son"
    @State private var customRecipient = ""
    @State private var occasion = "Birthday"
    @State private var selectedInterests: Set<GiftGuideInterest> = [.outdoors, .games, .making]
    @State private var isBuilding = false

    private let people = ["Leon", "Someone new"]
    private let occasions = ["Birthday", "Holiday", "Milestone", "Just because"]

    private var resolvedRecipient: String {
        recipient == "Someone new"
            ? customRecipient.trimmingCharacters(in: .whitespacesAndNewlines)
            : recipient
    }
    private var canSubmit: Bool {
        !resolvedRecipient.isEmpty && selectedInterests.count >= 3
    }

    var body: some View {
        ZStack {
            Color(hex: "#F5F5F2").ignoresSafeArea()
            if isBuilding {
                buildingView
                    .transition(.opacity)
            } else {
                form
                    .transition(.opacity)
            }
        }
        .environment(\.colorScheme, .light)
    }

    private var form: some View {
        VStack(spacing: 0) {
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.black)
                        .frame(width: 40, height: 40)
                        .background(.white.opacity(0.58), in: Circle())
                        .glassEffect(.regular, in: .circle)
                }
                Spacer()
                Text("New gift guide")
                    .font(GravityFont.semiBold.fixedFont(size: 15))
                Spacer()
                Color.clear.frame(width: 40, height: 40)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 28) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Find something they’ll love")
                            .font(GravityFont.expressiveBold.fixedFont(size: 32))
                            .tracking(-0.8)
                        Text("A few details are enough. You can steer the guide anytime.")
                            .font(GravityFont.regular.fixedFont(size: 16))
                            .foregroundStyle(.secondary)
                    }

                    section(title: "Who’s it for?") {
                        HStack(spacing: 8) {
                            ForEach(people, id: \.self) { person in
                                choiceChip(person, selection: $recipient)
                            }
                        }
                        if recipient == "Someone new" {
                            TextField("Their first name", text: $customRecipient)
                                .textInputAutocapitalization(.words)
                                .font(GravityFont.medium.fixedFont(size: 16))
                                .padding(.horizontal, 14)
                                .frame(height: 50)
                                .background(.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        } else {
                            Text("Shop already knows León is 10 and likes being outdoors.")
                                .font(GravityFont.regular.fixedFont(size: 13))
                                .foregroundStyle(.secondary)
                        }
                    }

                    section(title: "What’s the occasion?") {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(occasions, id: \.self) { value in
                                    choiceChip(value, selection: $occasion)
                                }
                            }
                        }
                        .contentMargins(.horizontal, 0, for: .scrollContent)
                    }

                    section(title: "What are they into?") {
                        Text("Choose at least three · \(selectedInterests.count) selected")
                            .font(GravityFont.regular.fixedFont(size: 13))
                            .foregroundStyle(selectedInterests.count >= 3 ? Color(hex: "#5433EB") : .secondary)

                        LazyVGrid(
                            columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3),
                            spacing: 8
                        ) {
                            ForEach(GiftGuideInterest.allCases) { interest in
                                interestButton(interest)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 26)
                .padding(.bottom, 112)
            }
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                buildGuide()
            } label: {
                Text("Show gift ideas")
                    .font(GravityFont.semiBold.fixedFont(size: 16))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(.black, in: Capsule())
            }
            .buttonStyle(PressScaleButtonStyle())
            .disabled(!canSubmit)
            .opacity(canSubmit ? 1 : 0.35)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)
        }
    }

    private var buildingView: some View {
        VStack(spacing: 24) {
            ZStack {
                ForEach(0..<4, id: \.self) { index in
                    Circle()
                        .fill(Color(hex: "#5433EB").opacity(1 - Double(index) * 0.16))
                        .frame(width: 54, height: 54)
                        .offset(x: CGFloat(index - 2) * 22)
                }
            }
            .frame(height: 70)
            Text("Building a guide for \(resolvedRecipient)")
                .font(GravityFont.expressiveBold.fixedFont(size: 25))
            Text("Finding thoughtful ideas across Shop")
                .font(GravityFont.regular.fixedFont(size: 15))
                .foregroundStyle(.secondary)
        }
    }

    private func section<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(GravityFont.expressiveBold.fixedFont(size: 21))
            content()
        }
    }

    private func choiceChip(_ value: String, selection: Binding<String>) -> some View {
        Button {
            HapticFeedback.selection.fire()
            selection.wrappedValue = value
        } label: {
            Text(value)
                .font(GravityFont.medium.fixedFont(size: 14))
                .foregroundStyle(selection.wrappedValue == value ? .white : .black)
                .padding(.horizontal, 14)
                .frame(height: 40)
                .background(selection.wrappedValue == value ? Color.black : Color.white, in: Capsule())
                .overlay { Capsule().strokeBorder(.black.opacity(0.1), lineWidth: 0.5) }
        }
        .buttonStyle(PressScaleButtonStyle())
    }

    private func interestButton(_ interest: GiftGuideInterest) -> some View {
        let selected = selectedInterests.contains(interest)
        return Button {
            HapticFeedback.selection.fire()
            if selected { selectedInterests.remove(interest) }
            else { selectedInterests.insert(interest) }
        } label: {
            ZStack(alignment: .topTrailing) {
                VStack(spacing: 8) {
                    Image(systemName: interest.symbol)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(selected ? Color(hex: "#5433EB") : .black)
                        .frame(width: 36, height: 36)
                        .background(.black.opacity(0.055), in: Circle())
                    Text(interest.title)
                        .font(GravityFont.medium.fixedFont(size: 12))
                        .foregroundStyle(.black)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .frame(height: 30, alignment: .top)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.top, 13)

                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color(hex: "#5433EB"))
                        .padding(8)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 100)
            .background(selected ? Color(hex: "#EEE8FF") : .white, in: RoundedRectangle(cornerRadius: GravityRadius.r16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: GravityRadius.r16, style: .continuous)
                    .strokeBorder(selected ? Color(hex: "#5433EB").opacity(0.7) : .black.opacity(0.07), lineWidth: selected ? 1 : 0.5)
            }
        }
        .buttonStyle(PressScaleButtonStyle())
    }

    private func buildGuide() {
        guard canSubmit else { return }
        HapticFeedback.medium.fire()
        withAnimation(.easeOut(duration: 0.2)) { isBuilding = true }
        let brief = GiftGuideBrief(
            recipientName: resolvedRecipient,
            relationship: recipient == "Someone new" ? "Someone" : relationship,
            occasion: occasion,
            interests: GiftGuideInterest.allCases.filter(selectedInterests.contains)
        )
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(1100))
            onComplete(brief)
        }
    }
}
