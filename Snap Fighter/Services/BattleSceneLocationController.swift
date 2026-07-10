import Combine
import CoreLocation
import Foundation
import MapKit
import UIKit

@MainActor
final class BattleSceneLocationController: NSObject, ObservableObject {
    @Published private(set) var authorizationStatus: CLAuthorizationStatus
    @Published private(set) var coordinate: CLLocationCoordinate2D?
    @Published private(set) var locality: String?
    @Published private(set) var errorMessage: String?
    @Published private(set) var isUsingLiveArena = false
    @Published private(set) var isLoadingLocation = false
    @Published private(set) var isLoadingLookAround = false
    @Published private(set) var lookAroundScene: MKLookAroundScene?
    @Published private(set) var lookAroundSnapshot: UIImage?
    @Published private(set) var lookAroundStatus: LookAroundStatus = .idle

    private let locationManager = CLLocationManager()
    private let geocoder = CLGeocoder()

    enum LookAroundStatus: Equatable {
        case idle
        case loading
        case available
        case unavailable
    }

    override init() {
        authorizationStatus = locationManager.authorizationStatus
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    var arenaTitle: String {
        if isUsingLiveArena, let locality, !locality.isEmpty {
            return "\(locality) 戰區"
        }

        if isUsingLiveArena {
            return "已同步目前位置"
        }

        switch authorizationStatus {
        case .denied, .restricted:
            return "位置權限未開啟"
        case .authorizedAlways, .authorizedWhenInUse:
            return "可同步附近戰場"
        case .notDetermined:
            return "尚未同步戰場"
        @unknown default:
            return "戰場資訊未就緒"
        }
    }

    var arenaSubtitle: String {
        if let errorMessage, !errorMessage.isEmpty {
            return errorMessage
        }

        if isLoadingLocation {
            return "正在定位附近街區並更新戰場。"
        }

        if isLoadingLookAround {
            return "正在嘗試抓取附近街景，成功後會切成更像戰場的實景背景。"
        }

        if isUsingLiveArena {
            switch lookAroundStatus {
            case .available:
                return "目前使用 Apple Maps Look Around 街景作為戰場背景。"
            case .unavailable:
                return "目前位置沒有街景覆蓋，已退回 Apple Maps 衛星地圖。"
            case .idle, .loading:
                return "目前使用 Apple Maps 本地衛星地形作為戰場背景。"
            }
        }

        switch authorizationStatus {
        case .denied, .restricted:
            return "前往系統設定開啟定位後，就能用目前位置生成戰場背景。"
        case .authorizedAlways, .authorizedWhenInUse:
            return "點擊右側按鈕，將目前位置同步為戰場背景。"
        case .notDetermined:
            return "首次啟用時會請求定位權限。"
        @unknown default:
            return "等待定位服務可用。"
        }
    }

    var actionTitle: String {
        isUsingLiveArena ? "關閉實景戰場" : "同步目前位置"
    }

    func toggleLiveArena() {
        errorMessage = nil

        if isUsingLiveArena {
            isUsingLiveArena = false
            isLoadingLookAround = false
            return
        }

        switch authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            requestCurrentLocation()
        case .notDetermined:
            isLoadingLocation = true
            locationManager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            isUsingLiveArena = false
            errorMessage = "定位權限被拒絕，無法同步目前位置。"
        @unknown default:
            isUsingLiveArena = false
            errorMessage = "定位服務暫時不可用。"
        }
    }

    private func requestCurrentLocation() {
        isLoadingLocation = true
        locationManager.requestLocation()
    }

    private func loadLookAroundScene(for coordinate: CLLocationCoordinate2D) {
        isLoadingLookAround = true
        lookAroundStatus = .loading

        let request = MKLookAroundSceneRequest(coordinate: coordinate)
        request.getSceneWithCompletionHandler { [weak self] scene, error in
            guard let self else { return }

            Task { @MainActor in
                self.isLoadingLookAround = false

                if let scene {
                    self.lookAroundScene = scene
                    self.lookAroundStatus = .available
                    self.loadLookAroundSnapshot(for: scene)
                    return
                }

                self.lookAroundScene = nil
                self.lookAroundSnapshot = nil
                self.lookAroundStatus = .unavailable

                if let nsError = error as NSError?, nsError.code != NSUserCancelledError {
                    self.errorMessage = "附近沒有可用街景，已改用衛星戰場。"
                }
            }
        }
    }

    private func loadLookAroundSnapshot(for scene: MKLookAroundScene) {
        let options = MKLookAroundSnapshotter.Options()
        options.size = CGSize(width: 1400, height: 2200)
        options.traitCollection = UITraitCollection(displayScale: UIScreen.main.scale)

        let snapshotter = MKLookAroundSnapshotter(scene: scene, options: options)
        snapshotter.getSnapshotWithCompletionHandler { [weak self] snapshot, _ in
            guard let self else { return }

            Task { @MainActor in
                self.lookAroundSnapshot = snapshot?.image
            }
        }
    }

    private func updateSceneName(for location: CLLocation) {
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, _ in
            guard let self else { return }

            Task { @MainActor in
                let placemark = placemarks?.first
                self.locality =
                    placemark?.subLocality ??
                    placemark?.locality ??
                    placemark?.administrativeArea
            }
        }
    }
}

extension BattleSceneLocationController: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus

        if isLoadingLocation {
            switch manager.authorizationStatus {
            case .authorizedAlways, .authorizedWhenInUse:
                requestCurrentLocation()
            case .denied, .restricted:
                isLoadingLocation = false
                errorMessage = "沒有定位權限，無法生成本地戰場背景。"
            case .notDetermined:
                break
            @unknown default:
                isLoadingLocation = false
                errorMessage = "定位權限狀態不明。"
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else {
            isLoadingLocation = false
            errorMessage = "沒有取得定位結果。"
            return
        }

        coordinate = location.coordinate
        isUsingLiveArena = true
        isLoadingLocation = false
        errorMessage = nil
        lookAroundScene = nil
        lookAroundSnapshot = nil
        lookAroundStatus = .idle
        updateSceneName(for: location)
        loadLookAroundScene(for: location.coordinate)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        isLoadingLocation = false
        isUsingLiveArena = false
        errorMessage = "定位失敗：\(error.localizedDescription)"
    }
}
