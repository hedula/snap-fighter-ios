import SwiftUI

struct DeckView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var deckStore: DeckStore

    private let columns = [
        GridItem(.adaptive(minimum: 160), spacing: 16, alignment: .top)
    ]

    var body: some View {
        NavigationStack {
            Group {
                if deckStore.deck.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            activeBattleDeckSection

                            LazyVGrid(columns: columns, spacing: 16) {
                                ForEach(deckStore.deck) { monster in
                                    VStack(alignment: .leading, spacing: 12) {
                                        CardView(monster: monster, layout: .compact)

                                        Button {
                                            _ = deckStore.toggleActiveBattleDeck(monster)
                                        } label: {
                                            Label(
                                                deckStore.isInActiveBattleDeck(monster) ? "取消出戰" : "設為出戰",
                                                systemImage: deckStore.isInActiveBattleDeck(monster) ? "checkmark.circle.fill" : "shield.lefthalf.filled"
                                            )
                                            .font(.subheadline)
                                            .frame(maxWidth: .infinity)
                                        }
                                        .buttonStyle(.borderedProminent)
                                        .tint(deckStore.isInActiveBattleDeck(monster) ? .green : .accentColor)
                                        .disabled(
                                            !deckStore.isInActiveBattleDeck(monster) &&
                                            deckStore.activeBattleDeckIDs.count >= 2
                                        )

                                        Button(role: .destructive) {
                                            deckStore.removeFromDeck(id: monster.id)
                                        } label: {
                                            Label("移出牌組", systemImage: "trash")
                                                .font(.subheadline)
                                                .frame(maxWidth: .infinity)
                                        }
                                        .buttonStyle(.bordered)
                                    }
                                }
                            }
                        }
                        .padding(20)
                    }
                }
            }
            .navigationTitle("我的牌組")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 18) {
            Image(systemName: "square.stack.3d.up.slash")
                .font(.system(size: 52))
                .foregroundColor(.secondary)
            Text("牌組目前是空的")
                .font(.title3)
                .bold()
            Text("先去贏下一場對戰，再把勝利卡收藏進來。")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }

    private var activeBattleDeckSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("目前出戰牌組")
                .font(.headline)
                .bold()

            if deckStore.activeBattleDeck.isEmpty {
                Text("從下方選兩張卡作為預設備戰卡。")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            } else {
                HStack(spacing: 12) {
                    ForEach(Array(deckStore.activeBattleDeck.enumerated()), id: \.element.id) { index, monster in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(index == 0 ? "主將" : "副將")
                                .font(.caption)
                                .bold()
                                .foregroundColor(.secondary)
                            CardView(monster: monster, layout: .compact)
                        }
                    }
                }
            }
        }
    }
}
