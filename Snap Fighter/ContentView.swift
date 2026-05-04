import SwiftUI

struct ContentView: View {
    @StateObject private var vm = GameViewModel()
    @State private var showImagePicker = false
    @State private var pickerSource: CameraView.Source = .camera

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            mainContent
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
                player2: vm.monsters[1]
            ) { winner in
                vm.endBattle(winner: winner)
            }

        case .result(let winner):
            resultView(winner: winner)
        }
    }

    private var idleView: some View {
        VStack(spacing: 32) {
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 80))
                .foregroundColor(.accentColor)
            Text("Snap Fighter")
                .font(.largeTitle)
                .bold()
            Text("拍攝物體，生成戰鬥角色！")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Button {
                openPicker(.camera)
            } label: {
                Label("拍照抓怪", systemImage: "camera.fill")
                    .font(.title2)
                    .bold()
                    .foregroundColor(.white)
                    .padding(.horizontal, 40)
                    .padding(.vertical, 14)
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
                    .padding(.horizontal, 30)
                    .padding(.vertical, 10)
                    .background(Color.accentColor.opacity(0.12))
                    .clipShape(Capsule())
            }
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

    private func showCardView(monster: Monster) -> some View {
        VStack(spacing: 24) {
            Text("你抓到了！")
                .font(.title2)
                .bold()
            CardView(monster: monster)
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
    }

    private var readyToBattleView: some View {
        VStack(spacing: 24) {
            Text("準備對戰！")
                .font(.title2)
                .bold()
            HStack(spacing: 12) {
                CardView(monster: vm.monsters[0])
                Text("VS")
                    .font(.title)
                    .bold()
                    .foregroundColor(.secondary)
                CardView(monster: vm.monsters[1])
            }
            .padding(.horizontal, 8)
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
    }

    private func resultView(winner: Monster) -> some View {
        VStack(spacing: 32) {
            Text("🏆")
                .font(.system(size: 80))
            Text("\(winner.name) 獲勝！")
                .font(.largeTitle)
                .bold()
                .multilineTextAlignment(.center)
            CardView(monster: winner)
                .padding(.horizontal, 40)
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
    }

    private func openPicker(_ source: CameraView.Source) {
        pickerSource = source
        showImagePicker = true
    }
}
