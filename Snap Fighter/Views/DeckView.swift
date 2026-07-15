import SwiftUI

struct DeckView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var deckStore: DeckStore

    private let columns = [
        GridItem(.flexible(), spacing: 12, alignment: .top),
        GridItem(.flexible(), spacing: 12, alignment: .top)
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                deckBackdrop

                if deckStore.deck.isEmpty {
                    emptyState
                } else {
                    deckCollection
                }
            }
            .navigationTitle("戰鬥編成")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(RPGTheme.midnight.opacity(0.96), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                        .fontWeight(.bold)
                        .foregroundStyle(RPGTheme.gold)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var deckBackdrop: some View {
        ZStack {
            Image("ArcaneArena")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
            RPGTheme.midnight.opacity(0.86)
                .ignoresSafeArea()
        }
    }

    private var deckCollection: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                activeBattleDeckSection

                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("卡牌收藏")
                            .font(.title2.weight(.black))
                            .foregroundStyle(.white)
                        Text("點選卡牌加入編成；長按可移出收藏。")
                            .font(.caption)
                            .foregroundStyle(RPGTheme.mist)
                    }
                    Spacer()
                    Text("\(deckStore.deck.count) CARDS")
                        .font(.caption2.weight(.black))
                        .tracking(1.2)
                        .foregroundStyle(RPGTheme.gold)
                }

                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(deckStore.deck) { monster in
                        deckCard(monster)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 18)
            .padding(.bottom, 34)
        }
    }

    private func deckCard(_ monster: Monster) -> some View {
        let isSelected = deckStore.isInActiveBattleDeck(monster)

        return Button {
            _ = deckStore.toggleActiveBattleDeck(monster)
        } label: {
            ZStack(alignment: .topTrailing) {
                CardView(monster: monster, layout: .compact)
                    .opacity(!isSelected && deckStore.activeBattleDeckIDs.count >= 2 ? 0.55 : 1)

                if isSelected {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.title2)
                        .foregroundStyle(RPGTheme.gold)
                        .padding(8)
                        .shadow(color: .black, radius: 3)
                        .accessibilityHidden(true)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(!isSelected && deckStore.activeBattleDeckIDs.count >= 2)
        .accessibilityLabel("\(monster.name)，\(isSelected ? "已加入出戰編成" : "加入出戰編成")")
        .contextMenu {
            Button(role: .destructive) {
                deckStore.removeFromDeck(id: monster.id)
            } label: {
                Label("移出收藏", systemImage: "trash")
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 18) {
            Image(systemName: "rectangle.stack.badge.plus")
                .font(.system(size: 46, weight: .bold))
                .foregroundStyle(RPGTheme.gold)
                .frame(width: 88, height: 88)
                .background(RPGTheme.panelRaised)
                .clipShape(Circle())
                .overlay(Circle().stroke(RPGTheme.goldDark, lineWidth: 2))

            Text("卡庫仍是一片空白")
                .font(.title2.weight(.black))
                .foregroundStyle(.white)

            Text("先完成一場對戰，把勝利怪物收進卡庫，\n再回來編成你的主將與副將。")
                .font(.subheadline)
                .foregroundStyle(RPGTheme.mist)
                .multilineTextAlignment(.center)

            Button("返回冒險大廳") { dismiss() }
                .font(.headline.weight(.black))
                .foregroundStyle(RPGTheme.ink)
                .padding(.horizontal, 28)
                .padding(.vertical, 13)
                .background(RPGTheme.gold)
                .clipShape(Capsule())
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var activeBattleDeckSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("出戰隊伍")
                        .font(.title2.weight(.black))
                        .foregroundStyle(.white)
                    Text(deckStore.activeBattleDeck.count == 2 ? "編成完成，可以挑戰 AI 對手。" : "選擇主將與副將，共兩張卡。")
                        .font(.caption)
                        .foregroundStyle(RPGTheme.mist)
                }
                Spacer()
                Text(deckStore.activeBattleDeck.count == 2 ? "READY" : "EDIT")
                    .font(.caption2.weight(.black))
                    .tracking(1.3)
                    .foregroundStyle(deckStore.activeBattleDeck.count == 2 ? Color.green : RPGTheme.gold)
            }

            HStack(spacing: 12) {
                formationSlot(index: 0, title: "主將")
                formationSlot(index: 1, title: "副將")
            }
        }
        .padding(16)
        .background(RPGTheme.panel.opacity(0.94))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(RPGTheme.goldDark.opacity(0.8), lineWidth: 1)
        }
    }

    @ViewBuilder
    private func formationSlot(index: Int, title: String) -> some View {
        if deckStore.activeBattleDeck.indices.contains(index) {
            let monster = deckStore.activeBattleDeck[index]
            Button {
                _ = deckStore.toggleActiveBattleDeck(monster)
            } label: {
                VStack(spacing: 7) {
                    Text(title)
                        .font(.caption.weight(.black))
                        .foregroundStyle(RPGTheme.gold)
                    CardView(monster: monster, layout: .compact)
                }
            }
            .buttonStyle(.plain)
            .accessibilityHint("點兩下可取消出戰")
        } else {
            VStack(spacing: 10) {
                Text(title)
                    .font(.caption.weight(.black))
                    .foregroundStyle(RPGTheme.gold)
                Image(systemName: "plus")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(RPGTheme.gold.opacity(0.8))
                Text("選擇卡牌")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(RPGTheme.mist)
            }
            .frame(maxWidth: .infinity, minHeight: 192)
            .background(RPGTheme.midnight.opacity(0.75))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(RPGTheme.goldDark, style: StrokeStyle(lineWidth: 1, dash: [6, 4]))
            }
        }
    }
}
