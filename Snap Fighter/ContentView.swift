import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var deckStore: DeckStore
    @StateObject private var vm = GameViewModel()
    @State private var showImagePicker = false
    @State private var showDeck = ProcessInfo.processInfo.arguments.contains("--show-deck")
    @State private var pickerSource: CameraView.Source = .camera
    @State private var didConfigureDebugPreview = false
    @State private var showManualCutoutPicker = false

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
        .sheet(isPresented: $showManualCutoutPicker) {
            if let sourceImage = vm.analysisProgress?.sourceImage ?? vm.lastCaptureImage {
                ManualSubjectLiftSheet(
                    image: sourceImage,
                    onComplete: { cutout in
                        vm.applyManualCutout(cutout)
                        showManualCutoutPicker = false
                    },
                    onCancel: {
                        showManualCutoutPicker = false
                    }
                )
            }
        }
        .alert("錯誤", isPresented: Binding(
            get: { vm.errorMessage != nil },
            set: { if !$0 { vm.errorMessage = nil } }
        )) {
            Button("確定") { vm.errorMessage = nil }
        } message: {
            Text(vm.errorMessage ?? "")
        }
        .onAppear {
            configureDebugPreviewStateIfNeeded()
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
        arcaneScreen {
            KeyOutProcessView(
                progress: vm.analysisProgress,
                onRetry: {
                    Task { await vm.retryLastCapture() }
                },
                onCancel: {
                    vm.cancelAnalysis()
                },
                onManualCutout: {
                    showManualCutoutPicker = true
                }
            )
        }
        .preferredColorScheme(.dark)
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
        arcaneScreen {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    ritualHeader(
                        eyebrow: "SUMMON COMPLETE",
                        title: "召喚成功",
                        subtitle: "現實物件已轉化為戰鬥卡牌"
                    )

                    ZStack {
                        Circle()
                            .fill(RPGTheme.gold.opacity(0.12))
                            .frame(width: 310, height: 310)
                            .overlay(Circle().stroke(RPGTheme.goldDark.opacity(0.7), lineWidth: 1))

                        CardView(monster: monster)
                            .frame(width: 286)
                            .rotationEffect(.degrees(-1.5))
                    }

                    if monster.capturedImage != nil, monster.cardImage != nil {
                        ForegroundPreviewSection(
                            monster: monster,
                            selectedArtwork: Binding(
                                get: { monster.preferredArtwork },
                                set: { vm.updateArtworkPreference($0, for: monster.id) }
                            )
                        )
                    }

                    VStack(spacing: 10) {
                        Text("再召喚 1 張卡，即可進入決鬥。")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(RPGTheme.mist)

                        Button {
                            openPicker(.camera)
                        } label: {
                            Label("召喚第二張卡", systemImage: "camera.fill")
                                .font(.headline.weight(.black))
                                .foregroundStyle(RPGTheme.ink)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(RPGTheme.gold)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }

                        Button {
                            openPicker(.photoLibrary)
                        } label: {
                            Label("從照片選擇", systemImage: "photo.on.rectangle")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(RPGTheme.parchment)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(RPGTheme.panelRaised)
                                .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                                        .stroke(RPGTheme.goldDark, lineWidth: 1)
                                }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 48)
                .padding(.bottom, 28)
            }
        }
        .preferredColorScheme(.dark)
    }

    private var readyToBattleView: some View {
        arcaneScreen {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    ritualHeader(
                        eyebrow: "BATTLE ASSEMBLY",
                        title: "決鬥編成",
                        subtitle: "確認出戰卡牌與屬性關係"
                    )

                    if vm.monsters.count >= 2 {
                        HStack(alignment: .center, spacing: 8) {
                            VStack(spacing: 7) {
                                Text("YOUR CARD")
                                    .font(.caption2.weight(.black))
                                    .tracking(1.1)
                                    .foregroundStyle(RPGTheme.gold)
                                CardView(monster: vm.monsters[0], layout: .compact)
                            }

                            Text("VS")
                                .font(.system(size: 15, weight: .black, design: .rounded))
                                .foregroundStyle(RPGTheme.parchment)
                                .frame(width: 38, height: 38)
                                .background(RPGTheme.panelRaised)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(RPGTheme.goldDark, lineWidth: 1))

                            VStack(spacing: 7) {
                                Text("RIVAL CARD")
                                    .font(.caption2.weight(.black))
                                    .tracking(1.1)
                                    .foregroundStyle(Color.red.opacity(0.9))
                                CardView(monster: vm.monsters[1], layout: .compact)
                            }
                        }

                        matchupPanel(attacker: vm.monsters[0], defender: vm.monsters[1])
                    }

                    if let reserve = vm.reserveMonster {
                        reserveReadyRow(reserve)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 48)
                .padding(.bottom, 116)
            }
        }
        .overlay(alignment: .bottom) {
            Button {
                vm.startBattle()
            } label: {
                HStack {
                    Image(systemName: "flame.fill")
                    Text("進入魔法競技場")
                    Spacer()
                    Image(systemName: "chevron.right")
                }
                .font(.headline.weight(.black))
                .foregroundStyle(.white)
                .padding(.horizontal, 18)
                .frame(height: 54)
                .background(Color(red: 0.72, green: 0.14, blue: 0.12))
                .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 8)
            .background(RPGTheme.midnight.opacity(0.96))
        }
        .preferredColorScheme(.dark)
    }

    private func matchupPanel(attacker: Monster, defender: Monster) -> some View {
        let effectiveness = attacker.element.effectivenessText(against: defender.element)

        return HStack(spacing: 12) {
            Image(systemName: attacker.element.symbolName)
                .font(.title3.weight(.black))
                .foregroundStyle(attacker.element.tintColor)
                .frame(width: 42, height: 42)
                .background(RPGTheme.panelRaised)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text("屬性預測")
                    .font(.caption2.weight(.black))
                    .tracking(1.1)
                    .foregroundStyle(RPGTheme.gold)
                Text(effectiveness ?? "雙方屬性勢均力敵。")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
            }

            Spacer()

            HStack(spacing: 5) {
                Text(attacker.element.rawValue)
                    .foregroundStyle(attacker.element.tintColor)
                Image(systemName: "arrow.right")
                    .foregroundStyle(RPGTheme.mist)
                Text(defender.element.rawValue)
                    .foregroundStyle(defender.element.tintColor)
            }
            .font(.headline.weight(.black))
        }
        .padding(14)
        .background(RPGTheme.panel.opacity(0.96))
        .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .stroke(RPGTheme.goldDark, lineWidth: 1)
        }
    }

    private func reserveReadyRow(_ reserve: Monster) -> some View {
        HStack(spacing: 12) {
            Group {
                if let artwork = reserve.displayArtwork {
                    Image(uiImage: artwork)
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(reserve.element.fallbackArtworkName)
                        .resizable()
                        .scaledToFill()
                }
            }
            .frame(width: 64, height: 64)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(RPGTheme.goldDark, lineWidth: 2)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("RESERVE · 副將待命")
                    .font(.caption2.weight(.black))
                    .tracking(1)
                    .foregroundStyle(RPGTheme.gold)
                Text(reserve.name)
                    .font(.headline.weight(.black))
                    .foregroundStyle(.white)
                Text(reserve.skillType.reserveEntryHint)
                    .font(.caption)
                    .foregroundStyle(RPGTheme.mist)
            }

            Spacer()

            Text("Lv.\(reserve.level)")
                .font(.subheadline.weight(.black))
                .foregroundStyle(RPGTheme.parchment)
        }
        .padding(12)
        .background(RPGTheme.panel.opacity(0.96))
        .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .stroke(RPGTheme.goldDark, lineWidth: 1)
        }
    }

    private func resultView(winner: Monster) -> some View {
        arcaneScreen {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    VStack(spacing: 9) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 42, weight: .black))
                            .foregroundStyle(RPGTheme.gold)
                            .shadow(color: RPGTheme.gold.opacity(0.35), radius: 10)

                        ritualHeader(
                            eyebrow: "BATTLE RESULT",
                            title: "勝者誕生",
                            subtitle: "\(winner.name) 贏得這場決鬥"
                        )
                    }

                    CardView(monster: winner)
                        .frame(width: 280)
                        .rotationEffect(.degrees(1.4))

                    if let reward = vm.battleReward, reward.monsterID == winner.id {
                        rewardPanel(reward, winner: winner)
                    } else {
                        victoryRecordPanel(winner)
                    }

                    VStack(spacing: 10) {
                        Button {
                            _ = deckStore.addToDeck(winner)
                        } label: {
                            Label(
                                deckStore.contains(winner) ? "已收藏這張卡" : "收入卡牌收藏",
                                systemImage: deckStore.contains(winner) ? "checkmark.seal.fill" : "rectangle.stack.badge.plus"
                            )
                            .font(.headline.weight(.black))
                            .foregroundStyle(deckStore.contains(winner) ? RPGTheme.gold : RPGTheme.ink)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(deckStore.contains(winner) ? RPGTheme.panelRaised : RPGTheme.gold)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(RPGTheme.goldDark, lineWidth: 1)
                            }
                        }
                        .disabled(deckStore.contains(winner))

                        Button {
                            vm.resetMonsters()
                        } label: {
                            Label("返回冒險大廳", systemImage: "house.fill")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(RPGTheme.parchment)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(RPGTheme.panelRaised)
                                .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 46)
                .padding(.bottom, 30)
            }
        }
        .preferredColorScheme(.dark)
    }

    private func arcaneScreen<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ZStack {
            Image("ArcaneArena")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
            RPGTheme.midnight.opacity(0.86)
                .ignoresSafeArea()
            content()
        }
    }

    private func ritualHeader(eyebrow: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 5) {
            Text(eyebrow)
                .font(.system(size: 10, weight: .black, design: .rounded))
                .tracking(2)
                .foregroundStyle(RPGTheme.gold)
            Text(title)
                .font(.system(size: 30, weight: .black, design: .rounded))
                .foregroundStyle(.white)
            Text(subtitle)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(RPGTheme.mist)
                .multilineTextAlignment(.center)
        }
    }

    private func rewardPanel(_ reward: GameViewModel.BattleReward, winner: Monster) -> some View {
        HStack(spacing: 14) {
            Image(systemName: "sparkles")
                .font(.title2.weight(.black))
                .foregroundStyle(RPGTheme.gold)
            VStack(alignment: .leading, spacing: 3) {
                Text(reward.levelsGained > 0 ? "LEVEL UP" : "BATTLE EXP")
                    .font(.caption2.weight(.black))
                    .tracking(1.3)
                    .foregroundStyle(RPGTheme.gold)
                Text(reward.levelsGained > 0 ? "獲得 \(reward.experienceGained) EXP · Lv.\(winner.level)" : "獲得 \(reward.experienceGained) EXP")
                    .font(.headline.weight(.black))
                    .foregroundStyle(.white)
            }
            Spacer()
            Text("+\(reward.experienceGained)")
                .font(.title3.weight(.black))
                .foregroundStyle(RPGTheme.parchment)
        }
        .padding(15)
        .background(RPGTheme.panel.opacity(0.96))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(RPGTheme.goldDark, lineWidth: 1)
        }
    }

    private func victoryRecordPanel(_ winner: Monster) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "shield.checkered")
                .font(.title2.weight(.bold))
                .foregroundStyle(RPGTheme.gold)
            VStack(alignment: .leading, spacing: 3) {
                Text("VICTORY RECORD")
                    .font(.caption2.weight(.black))
                    .tracking(1.2)
                    .foregroundStyle(RPGTheme.gold)
                Text("Lv.\(winner.level) · \(winner.element.rawValue)屬性 · \(winner.skill)")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
            }
            Spacer()
        }
        .padding(15)
        .background(RPGTheme.panel.opacity(0.96))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(RPGTheme.goldDark, lineWidth: 1)
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

    private func configureDebugPreviewStateIfNeeded() {
        #if DEBUG
        guard !didConfigureDebugPreview else { return }

        let arguments = ProcessInfo.processInfo.arguments
        let debugArguments = [
            "--show-capture-result",
            "--show-battle-result",
            "--show-keyout-process",
            "--show-keyout-preview",
            "--show-manual-cutout",
            "--show-ready-battle"
        ]
        guard debugArguments.contains(where: arguments.contains) else {
            return
        }

        didConfigureDebugPreview = true
        let artwork = UIImage(named: "FlameLampKnight")
        let sample = Monster(
            name: "朱焰燈騎",
            element: .fire,
            hp: 88,
            atk: 74,
            def: 46,
            skill: "燈火衝鋒",
            skillType: .powerStrike,
            capturedImage: artwork,
            cardImage: artwork,
            preferredArtwork: .original,
            level: 3,
            experience: 40
        )

        if arguments.contains("--show-keyout-process") {
            vm.analysisProgress = .init(
                phase: .removingBackground,
                sourceImage: artwork ?? UIImage(),
                cutoutImage: nil
            )
            vm.state = .analyzing
        } else if arguments.contains("--show-keyout-preview") {
            vm.analysisProgress = .init(
                phase: .detectingSubject,
                sourceImage: artwork ?? UIImage(),
                cutoutImage: nil
            )
            vm.state = .analyzing
            Task {
                let cutout = await ForegroundIsolationService.shared.isolateSubject(from: artwork ?? UIImage())
                vm.analysisProgress = .init(
                    phase: .generatingCard,
                    sourceImage: artwork ?? UIImage(),
                    cutoutImage: cutout
                )
            }
        } else if arguments.contains("--show-manual-cutout") {
            vm.analysisProgress = .init(
                phase: .generatingCard,
                sourceImage: artwork ?? UIImage(),
                cutoutImage: nil
            )
            vm.state = .analyzing
            DispatchQueue.main.async {
                showManualCutoutPicker = true
            }
        } else if arguments.contains("--show-ready-battle") {
            let rivalArtwork = UIImage(named: "TideBottleGuardian")
            let rival = Monster(
                name: "潮瓶守衛",
                element: .water,
                hp: 94,
                atk: 58,
                def: 72,
                skill: "潮壁反擊",
                skillType: .fortify,
                capturedImage: rivalArtwork,
                cardImage: rivalArtwork,
                preferredArtwork: .cutout,
                level: 4
            )
            vm.prepareBattle(with: [sample, rival])
        } else {
            vm.monsters = [sample]
            vm.state = arguments.contains("--show-capture-result") ? .showCard(sample) : .result(sample)
        }
        #endif
    }
}

private struct KeyOutProcessView: View {
    let progress: MonsterAnalysisProgress?
    let onRetry: () -> Void
    let onCancel: () -> Void
    let onManualCutout: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var scanAtBottom = false
    @State private var showRecoveryActions = false

    private var phase: MonsterAnalysisPhase {
        progress?.phase ?? .preparing
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 18) {
                VStack(spacing: 7) {
                    Text("KEY-OUT RITUAL")
                        .font(.caption.weight(.black))
                        .tracking(2.1)
                        .foregroundStyle(RPGTheme.gold)
                    Text("正在召喚怪物")
                        .font(.system(size: 30, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                    Text("保留物件輪廓，將現實影像轉化為透明卡面")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(RPGTheme.mist)
                        .multilineTextAlignment(.center)
                }

                imageStage

                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(phase.title)
                                .font(.headline.weight(.black))
                                .foregroundStyle(.white)
                            Text(phase.detail)
                                .font(.caption)
                                .foregroundStyle(RPGTheme.mist)
                        }
                        Spacer()
                        Text("\(Int(phase.progress * 100))%")
                            .font(.headline.monospacedDigit().weight(.black))
                            .foregroundStyle(RPGTheme.gold)
                    }

                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule().fill(RPGTheme.panelRaised)
                            Capsule()
                                .fill(RPGTheme.gold)
                                .frame(width: proxy.size.width * phase.progress)
                        }
                    }
                    .frame(height: 7)
                    .animation(.easeInOut(duration: 0.4), value: phase.progress)
                }
                .padding(15)
                .background(RPGTheme.panel.opacity(0.96))
                .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 17, style: .continuous)
                        .stroke(RPGTheme.goldDark, lineWidth: 1)
                }

                if phase == .generatingCard, progress?.cutoutImage == nil {
                    Button(action: onManualCutout) {
                        HStack(spacing: 10) {
                            Image(systemName: "hand.tap.fill")
                                .font(.headline.weight(.black))
                            VStack(alignment: .leading, spacing: 2) {
                                Text("手動去背")
                                    .font(.subheadline.weight(.black))
                                Text("點一下照片中的主體")
                                    .font(.caption2.weight(.medium))
                                    .foregroundStyle(RPGTheme.mist)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                        }
                        .foregroundStyle(RPGTheme.parchment)
                        .padding(.horizontal, 14)
                        .frame(height: 52)
                        .background(RPGTheme.panelRaised)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(RPGTheme.gold, lineWidth: 1)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("manual-cutout-button")
                    .accessibilityLabel("手動去背")
                    .accessibilityHint("開啟 Apple VisionKit 主體選取工具")
                }

                HStack(spacing: 0) {
                    ForEach(MonsterAnalysisPhase.allCases, id: \.rawValue) { item in
                        phaseMarker(item)
                        if item != MonsterAnalysisPhase.allCases.last {
                            Rectangle()
                                .fill(item.rawValue < phase.rawValue ? RPGTheme.gold : RPGTheme.panelRaised)
                                .frame(height: 1)
                        }
                    }
                }
                .accessibilityElement(children: .contain)

                if showRecoveryActions {
                    recoveryPanel
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 42)
            .padding(.bottom, 24)
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.45).repeatForever(autoreverses: true)) {
                scanAtBottom = true
            }
        }
        .task {
            try? await Task.sleep(nanoseconds: 10_000_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.25)) {
                showRecoveryActions = true
            }
        }
    }

    private var recoveryPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("比平常久了一點")
                    .font(.subheadline.weight(.black))
                    .foregroundStyle(.white)
                Text("可以繼續等待，或重新送出這張照片。")
                    .font(.caption)
                    .foregroundStyle(RPGTheme.mist)
            }

            HStack(spacing: 10) {
                Button(action: onCancel) {
                    Label("取消召喚", systemImage: "xmark")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(RPGTheme.parchment)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(RPGTheme.panelRaised)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                Button(action: onRetry) {
                    Label("重新嘗試", systemImage: "arrow.clockwise")
                        .font(.subheadline.weight(.black))
                        .foregroundStyle(RPGTheme.ink)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(RPGTheme.gold)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
        }
        .padding(14)
        .background(RPGTheme.panel.opacity(0.97))
        .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .stroke(RPGTheme.goldDark, lineWidth: 1)
        }
    }

    private var imageStage: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(RPGTheme.panel)

            if let cutout = progress?.cutoutImage {
                Image(uiImage: cutout)
                    .resizable()
                    .scaledToFit()
                    .padding(18)
                    .transition(.scale(scale: 0.92).combined(with: .opacity))

            } else if let source = progress?.sourceImage {
                Image(uiImage: source)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                    .opacity(0.74)

                if phase != .generatingCard {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [.clear, RPGTheme.gold.opacity(0.85), .clear],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(height: 3)
                        .shadow(color: RPGTheme.gold, radius: 8)
                        .offset(y: scanAtBottom ? 118 : -118)

                    Image(systemName: "viewfinder")
                        .font(.system(size: 250, weight: .ultraLight))
                        .foregroundStyle(RPGTheme.parchment.opacity(0.8))
                }

            } else {
                Image(systemName: "camera.filters")
                    .font(.system(size: 68, weight: .light))
                    .foregroundStyle(RPGTheme.gold)
            }
        }
        .frame(height: 286)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(alignment: .bottom) {
            if progress?.cutoutImage != nil {
                Label("背景已移除", systemImage: "checkmark.seal.fill")
                    .font(.caption.weight(.black))
                    .foregroundStyle(RPGTheme.ink)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(RPGTheme.gold)
                    .clipShape(Capsule())
                    .padding(12)
                    .accessibilityIdentifier("keyout-success")
            } else if phase == .generatingCard {
                Label("未找到明確輪廓，保留原始照片", systemImage: "photo.fill")
                    .font(.caption.weight(.black))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(RPGTheme.panelRaised.opacity(0.94))
                    .clipShape(Capsule())
                    .padding(12)
                    .accessibilityIdentifier("keyout-fallback")
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(RPGTheme.goldDark, lineWidth: 1.5)
        }
        .shadow(color: RPGTheme.gold.opacity(0.13), radius: 16)
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: progress?.cutoutImage != nil)
        .accessibilityLabel(
            progress?.cutoutImage != nil
                ? "背景已移除"
                : phase == .generatingCard
                    ? "未找到明確輪廓，保留原始照片"
                    : "正在掃描物件輪廓"
        )
    }

    private func phaseMarker(_ item: MonsterAnalysisPhase) -> some View {
        let isComplete = item.rawValue < phase.rawValue
        let isCurrent = item == phase

        return VStack(spacing: 6) {
            Image(systemName: isComplete ? "checkmark.circle.fill" : item.systemImage)
                .font(.caption.weight(.black))
                .foregroundStyle(isComplete || isCurrent ? RPGTheme.gold : RPGTheme.mist.opacity(0.55))
                .frame(width: 28, height: 28)
                .background(isCurrent ? RPGTheme.gold.opacity(0.14) : Color.clear)
                .clipShape(Circle())
            Text(item.title)
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(isCurrent ? .white : RPGTheme.mist)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
        }
        .frame(width: 58)
        .accessibilityLabel("\(item.title)，\(isComplete ? "已完成" : isCurrent ? "進行中" : "等待中")")
    }
}

private struct ForegroundPreviewSection: View {
    let monster: Monster
    @Binding var selectedArtwork: ArtworkPreference

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("選擇卡面")
                        .font(.headline.weight(.black))
                        .foregroundStyle(.white)
                    Text("收藏與戰鬥會使用你選擇的版本")
                        .font(.caption2)
                        .foregroundStyle(RPGTheme.mist)
                }
                Spacer()
                Image(systemName: "photo.badge.checkmark")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(RPGTheme.gold)
            }

            HStack(spacing: 10) {
                artworkChoice(
                    title: "原始照片",
                    image: monster.capturedImage,
                    preference: .original
                )
                artworkChoice(
                    title: "主體卡圖",
                    image: monster.cardImage ?? monster.capturedImage,
                    preference: .cutout
                )
            }
        }
        .padding(14)
        .background(RPGTheme.panel.opacity(0.96))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(RPGTheme.goldDark, lineWidth: 1)
        }
    }

    private func artworkChoice(title: String, image: UIImage?, preference: ArtworkPreference) -> some View {
        let isSelected = selectedArtwork == preference

        return Button {
            selectedArtwork = preference
        } label: {
            VStack(spacing: 6) {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                }

                HStack(spacing: 5) {
                    Text(title)
                        .font(.caption2.weight(.black))
                        .foregroundStyle(isSelected ? RPGTheme.ink : .white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    Spacer(minLength: 0)
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isSelected ? RPGTheme.ink : RPGTheme.gold)
                }
            }
            .padding(8)
            .frame(maxWidth: .infinity)
            .background(isSelected ? RPGTheme.gold : RPGTheme.panelRaised)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title)，\(isSelected ? "已選擇" : "未選擇")")
    }
}
