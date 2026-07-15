import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var deckStore: DeckStore
    @StateObject private var vm = GameViewModel()
    @State private var showImagePicker = false
    @State private var showDeck = ProcessInfo.processInfo.arguments.contains("--show-deck")
    @State private var pickerSource: CameraView.Source = .camera

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            mainContent
            diagnosticsOverlay
        }
        .sheet(isPresented: $showImagePicker) {
            CameraView(
                source: pickerSource,
                onImagePicked: { image in
                    Task { await vm.captureMonster(from: image) }
                },
                onDismiss: { showImagePicker = false }
            )
        }
        .sheet(isPresented: $showDeck) {
            DeckView()
                .environmentObject(deckStore)
        }
        .alert("錯誤", isPresented: Binding(
            get: { vm.errorMessage != nil },
            set: { if !$0 { vm.errorMessage = nil } }
        )) {
            Button("確定") { vm.errorMessage = nil }
        } message: {
            Text(vm.errorMessage ?? "")
        }
    }

    @ViewBuilder
    private var mainContent: some View {
        switch vm.state {
        case .idle:
            idleView

        case .capturing:
            EmptyView()

        case .analyzing:
            analyzingView

        case .showCard(let monster):
            showCardView(monster: monster)

        case .readyToBattle:
            readyToBattleView

        case .battling:
            BattleView(
                player1: vm.monsters[0],
                player2: vm.monsters[1],
                reservePlayer: vm.reserveMonster
            ) { winner in
                vm.endBattle(winner: winner, deckStore: deckStore)
            }

        case .result(let winner):
            resultView(winner: winner)
        }
    }

    private var idleView: some View {
        ZStack {
            Image("ArcaneArena")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()

            RPGTheme.midnight.opacity(0.82)
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    lobbyHeader
                    lobbyHero
                    quickBattlePanel

                    HStack(alignment: .top, spacing: 12) {
                        captureMissionPanel
                        deckMissionPanel
                    }

                    Text("拍下現實物件，召喚只屬於你的戰鬥卡。")
                        .font(.caption)
                        .foregroundStyle(RPGTheme.mist)
                        .padding(.top, 2)
                }
                .padding(.horizontal, 16)
                .padding(.top, 44)
                .padding(.bottom, 30)
            }
        }
        .preferredColorScheme(.dark)
    }

    private var lobbyHeader: some View {
        HStack(spacing: 10) {
            Image(systemName: "camera.aperture")
                .font(.title2.weight(.black))
                .foregroundStyle(RPGTheme.gold)

            VStack(alignment: .leading, spacing: 1) {
                Text("SNAP FIGHTER")
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .tracking(1.2)
                    .foregroundStyle(.white)
                Text("ARCANE CARD BATTLE")
                    .font(.system(size: 8, weight: .bold, design: .rounded))
                    .tracking(1.6)
                    .foregroundStyle(RPGTheme.gold)
            }

            Spacer()

            Button {
                showDeck = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "rectangle.stack.fill")
                    Text("\(deckStore.deck.count)")
                }
                .font(.subheadline.weight(.black))
                .foregroundStyle(RPGTheme.parchment)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(RPGTheme.panelRaised.opacity(0.96))
                .clipShape(Capsule())
                .overlay(Capsule().stroke(RPGTheme.goldDark, lineWidth: 1))
            }
            .accessibilityLabel("開啟牌組，目前有 \(deckStore.deck.count) 張卡")
        }
    }

    private var lobbyHero: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text("冒險大廳")
                    .font(.system(size: 30, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                Text("現實召喚 × 卡牌決鬥")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(RPGTheme.gold)
                Text("召喚身邊的物件，編成兩張卡牌，向魔法競技場發起挑戰。")
                    .font(.caption)
                    .foregroundStyle(RPGTheme.mist)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            ZStack {
                lobbyArt("TideBottleGuardian", rotation: 8, offset: CGSize(width: 23, height: 5))
                lobbyArt("FlameLampKnight", rotation: -7, offset: CGSize(width: -23, height: 0))
            }
            .frame(width: 140, height: 154)
        }
        .padding(16)
        .background(RPGTheme.panel.opacity(0.9))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(RPGTheme.goldDark.opacity(0.85), lineWidth: 1)
        }
    }

    private func lobbyArt(_ name: String, rotation: Double, offset: CGSize) -> some View {
        Image(name)
            .resizable()
            .scaledToFill()
            .frame(width: 88, height: 128)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(RPGTheme.gold, lineWidth: 3)
            }
            .rotationEffect(.degrees(rotation))
            .offset(offset)
            .shadow(color: .black.opacity(0.55), radius: 6, y: 5)
    }

    private var quickBattlePanel: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("STORY 01")
                        .font(.caption2.weight(.black))
                        .tracking(1.4)
                        .foregroundStyle(RPGTheme.gold)
                    Text("初次召喚試煉")
                        .font(.title3.weight(.black))
                        .foregroundStyle(.white)
                    Text("使用炎燈先鋒與潮瓶守衛，熟悉四種戰鬥指令。")
                        .font(.caption)
                        .foregroundStyle(RPGTheme.mist)
                }
                Spacer()
                Image(systemName: "flag.checkered.2.crossed")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(RPGTheme.gold)
            }

            Button {
                vm.prepareStarterBattle()
            } label: {
                HStack {
                    Image(systemName: "play.fill")
                    Text("快速開戰")
                    Spacer()
                    Text("推薦")
                        .font(.caption2.weight(.black))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(RPGTheme.ink.opacity(0.12))
                        .clipShape(Capsule())
                }
                .font(.headline.weight(.black))
                .foregroundStyle(RPGTheme.ink)
                .padding(.horizontal, 16)
                .frame(height: 48)
                .background(RPGTheme.gold)
                .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
            }
        }
        .padding(15)
        .background(RPGTheme.panelRaised.opacity(0.94))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(RPGTheme.gold.opacity(0.55), lineWidth: 1)
        }
    }

    private var captureMissionPanel: some View {
        VStack(alignment: .leading, spacing: 9) {
            missionPanelHeader(icon: "camera.fill", title: "現實召喚", subtitle: "拍攝物件製成卡牌")

            Button {
                openPicker(.camera)
            } label: {
                Label("拍照抓怪", systemImage: "viewfinder")
                    .font(.subheadline.weight(.black))
                    .frame(maxWidth: .infinity)
                    .frame(height: 42)
            }
            .foregroundStyle(RPGTheme.ink)
            .background(RPGTheme.parchment)
            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))

            Button {
                openPicker(.photoLibrary)
            } label: {
                Label("使用照片", systemImage: "photo.on.rectangle")
                    .font(.caption.weight(.bold))
                    .frame(maxWidth: .infinity)
            }
            .foregroundStyle(RPGTheme.gold)
        }
        .padding(13)
        .frame(maxWidth: .infinity, minHeight: 160, alignment: .topLeading)
        .background(RPGTheme.panel.opacity(0.94))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(RPGTheme.goldDark.opacity(0.8), lineWidth: 1)
        }
    }

    private var deckMissionPanel: some View {
        VStack(alignment: .leading, spacing: 9) {
            missionPanelHeader(icon: "rectangle.stack.fill", title: "牌組遠征", subtitle: deckStore.activeBattleDeck.count == 2 ? "隊伍已完成編成" : "選擇主將與副將")

            if deckStore.activeBattleDeck.count == 2 {
                Button {
                    vm.prepareBattleAgainstAI(with: deckStore.activeBattleDeck)
                } label: {
                    Label("挑戰 AI", systemImage: "flame.fill")
                        .font(.subheadline.weight(.black))
                        .frame(maxWidth: .infinity)
                        .frame(height: 42)
                }
                .foregroundStyle(.white)
                .background(Color(red: 0.72, green: 0.14, blue: 0.12))
                .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
            } else {
                Button {
                    showDeck = true
                } label: {
                    Label("編成牌組", systemImage: "plus")
                        .font(.subheadline.weight(.black))
                        .frame(maxWidth: .infinity)
                        .frame(height: 42)
                }
                .foregroundStyle(RPGTheme.ink)
                .background(RPGTheme.parchment)
                .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
            }

            Button {
                showDeck = true
            } label: {
                Text("查看卡庫 · \(deckStore.deck.count) 張")
                    .font(.caption.weight(.bold))
                    .frame(maxWidth: .infinity)
            }
            .foregroundStyle(RPGTheme.gold)
        }
        .padding(13)
        .frame(maxWidth: .infinity, minHeight: 160, alignment: .topLeading)
        .background(RPGTheme.panel.opacity(0.94))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(RPGTheme.goldDark.opacity(0.8), lineWidth: 1)
        }
    }

    private func missionPanelHeader(icon: String, title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Image(systemName: icon)
                .font(.headline.weight(.black))
                .foregroundStyle(RPGTheme.gold)
            Text(title)
                .font(.headline.weight(.black))
                .foregroundStyle(.white)
            Text(subtitle)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(RPGTheme.mist)
                .lineLimit(2)
        }
    }

    private var analyzingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            Text("AI 分析中...")
                .font(.title3)
                .foregroundColor(.secondary)
        }
    }

    @ViewBuilder
    private var diagnosticsOverlay: some View {
        #if DEBUG
        if isAIDebugOverlayEnabled, let diagnostics = vm.diagnostics {
            VStack {
                HStack {
                    Spacer()
                    VStack(alignment: .leading, spacing: 4) {
                        Text("AI Debug")
                            .font(.caption)
                            .bold()
                        Text(diagnostics.provider)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(diagnostics.model)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                    .padding(10)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(radius: 6)
                }
                Spacer()
            }
            .padding()
        }
        #endif
    }

    private var isAIDebugOverlayEnabled: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains("--show-ai-debug-overlay")
        #else
        return false
        #endif
    }

    private func showCardView(monster: Monster) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                Text("你抓到了！")
                    .font(.title2)
                    .bold()

                if monster.capturedImage != nil, monster.cardImage != nil {
                    ForegroundPreviewSection(
                        monster: monster,
                        selectedArtwork: Binding(
                            get: { monster.preferredArtwork },
                            set: { vm.updateArtworkPreference($0, for: monster.id) }
                        )
                    )
                        .padding(.horizontal, 24)
                }

                CardView(monster: monster)
                    .frame(maxWidth: 420)
                    .padding(.horizontal, 24)
                Button {
                    openPicker(.camera)
                } label: {
                    Label("再抓一隻", systemImage: "camera.fill")
                        .font(.title3)
                        .bold()
                        .foregroundColor(.white)
                        .padding(.horizontal, 36)
                        .padding(.vertical, 12)
                        .background(Color.accentColor)
                        .clipShape(Capsule())
                }

                Button {
                    openPicker(.photoLibrary)
                } label: {
                    Label("使用照片", systemImage: "photo.on.rectangle")
                        .font(.headline)
                        .bold()
                        .foregroundColor(.accentColor)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .background(Color.accentColor.opacity(0.12))
                        .clipShape(Capsule())
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
        }
    }

    private var readyToBattleView: some View {
        ScrollView {
            VStack(spacing: 24) {
                Text("準備對戰！")
                    .font(.title2)
                    .bold()
                GeometryReader { proxy in
                    let sidePadding: CGFloat = 24
                    let spacing: CGFloat = 12
                    let vsWidth: CGFloat = 28
                    let cardWidth = max(140, (proxy.size.width - sidePadding * 2 - spacing * 2 - vsWidth) / 2)

                    HStack(alignment: .top, spacing: spacing) {
                        CardView(monster: vm.monsters[0], layout: .compact)
                            .frame(width: cardWidth)
                        Text("VS")
                            .font(.title3)
                            .bold()
                            .foregroundColor(.secondary)
                            .frame(width: vsWidth)
                            .padding(.top, 80)
                        CardView(monster: vm.monsters[1], layout: .compact)
                            .frame(width: cardWidth)
                    }
                    .frame(maxWidth: .infinity)
                }
                .frame(height: 360)

                if let reserve = vm.reserveMonster {
                    VStack(spacing: 10) {
                        Text("副將待命")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        CardView(monster: reserve, layout: .compact)
                            .frame(maxWidth: 190)
                    }
                }

                Button {
                    vm.startBattle()
                } label: {
                    Label("對戰！", systemImage: "flame.fill")
                        .font(.title2)
                        .bold()
                        .foregroundColor(.white)
                        .padding(.horizontal, 40)
                        .padding(.vertical, 14)
                        .background(Color.red)
                        .clipShape(Capsule())
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
        }
    }

    private func resultView(winner: Monster) -> some View {
        ScrollView {
            VStack(spacing: 32) {
                Text("🏆")
                    .font(.system(size: 80))
                Text("\(winner.name) 獲勝！")
                    .font(.largeTitle)
                    .bold()
                    .multilineTextAlignment(.center)

                if let reward = vm.battleReward, reward.monsterID == winner.id {
                    Text(
                        reward.levelsGained > 0
                        ? "出戰卡獲得 \(reward.experienceGained) EXP，升到 Lv.\(winner.level)"
                        : "出戰卡獲得 \(reward.experienceGained) EXP"
                    )
                    .font(.headline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                }

                CardView(monster: winner)
                    .frame(maxWidth: 420)
                    .padding(.horizontal, 24)
                Button {
                    _ = deckStore.addToDeck(winner)
                } label: {
                    Label(deckStore.contains(winner) ? "已加入牌組" : "加入我的牌組", systemImage: deckStore.contains(winner) ? "checkmark.circle.fill" : "plus.circle.fill")
                        .font(.headline)
                        .bold()
                        .foregroundColor(deckStore.contains(winner) ? .accentColor : .white)
                        .padding(.horizontal, 28)
                        .padding(.vertical, 12)
                        .background(deckStore.contains(winner) ? Color.accentColor.opacity(0.14) : Color.accentColor)
                        .clipShape(Capsule())
                }
                .disabled(deckStore.contains(winner))

                if !deckStore.deck.isEmpty {
                    deckPreviewSection
                        .padding(.horizontal, 24)
                }

                Button {
                    vm.resetMonsters()
                } label: {
                    Text("再玩一次")
                        .font(.title2)
                        .bold()
                        .foregroundColor(.white)
                        .padding(.horizontal, 40)
                        .padding(.vertical, 14)
                        .background(Color.accentColor)
                        .clipShape(Capsule())
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
        }
    }

    private func openPicker(_ source: CameraView.Source) {
        pickerSource = source
        showImagePicker = true
    }

    private var deckModeSubtitle: String {
        if deckStore.activeBattleDeck.count == 2 {
            return "已選好兩張出戰卡，第一張主將先上，倒下後第二張副將會接戰。"
        }

        return "先到牌組頁選滿兩張出戰卡，再從這裡挑戰隨機 AI 對手。"
    }

    private var deckPreviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("我的牌組")
                    .font(.headline)
                    .bold()
                Spacer()
                Button {
                    showDeck = true
                } label: {
                    Text(deckStore.deck.isEmpty ? "查看" : "管理")
                        .font(.subheadline)
                        .bold()
                }
                Text("\(deckStore.deck.count) 張")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            activeBattleDeckSummary

            if deckStore.deck.isEmpty {
                Text("贏下對戰後，就能把勝利卡加入這裡。")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(deckStore.deck) { monster in
                            CardView(monster: monster, layout: .compact)
                                .frame(width: 180)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .frame(maxWidth: 520)
    }

    private func battleModeCard<Content: View>(
        title: String,
        subtitle: String,
        accent: Color,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: systemImage)
                    .font(.title2)
                    .foregroundColor(accent)
                    .frame(width: 36, height: 36)
                    .background(accent.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.title3)
                        .bold()
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            content()
        }
        .padding(20)
        .frame(maxWidth: 520, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }

    @ViewBuilder
    private var activeBattleDeckSummary: some View {
        if deckStore.activeBattleDeck.isEmpty {
            Text("尚未設定出戰牌組。可在牌組頁選兩張卡作為預設備戰卡。")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
        } else {
            VStack(alignment: .leading, spacing: 10) {
                Text("目前出戰（\(deckStore.activeBattleDeck.count)/2）")
                    .font(.subheadline)
                    .bold()

                HStack(spacing: 12) {
                    ForEach(deckStore.activeBattleDeck) { monster in
                        CardView(monster: monster, layout: .compact)
                            .frame(width: 180)
                    }
                }
            }
        }
    }
}

private struct ForegroundPreviewSection: View {
    let monster: Monster
    @Binding var selectedArtwork: ArtworkPreference

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("主體預覽")
                    .font(.headline)
                    .bold()
                Spacer()
                Text("選擇要存成卡面的版本")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Picker("卡面版本", selection: $selectedArtwork) {
                Text("原圖").tag(ArtworkPreference.original)
                Text("去背卡圖").tag(ArtworkPreference.cutout)
            }
            .pickerStyle(.segmented)

            Text(selectedArtwork == .cutout ? "目前會使用去背主體作為卡面。" : "目前會保留原始照片作為卡面。")
                .font(.caption)
                .foregroundColor(.secondary)

            if let image = selectedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, minHeight: 200, maxHeight: 260)
                    .padding(18)
                    .background(previewBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                    )
            }
        }
    }

    private var selectedImage: UIImage? {
        switch selectedArtwork {
        case .original:
            return monster.capturedImage
        case .cutout:
            return monster.cardImage ?? monster.capturedImage
        }
    }

    private var previewBackground: some ShapeStyle {
        switch selectedArtwork {
        case .original:
            return AnyShapeStyle(Color(.secondarySystemBackground))
        case .cutout:
            return AnyShapeStyle(
                LinearGradient(
                    colors: [Color.white, Color(.systemGray6)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }
    }
}
