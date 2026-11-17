//
//  ScanViewModel.swift
//  BluetoothScan
//
//  Created by Кирилл Чернов on 10.11.2026.
//

import Foundation

final class ScanViewModel {
    enum State: Equatable {
        case idle
        case waiting
        case scanning
        case finished
        case timedOut
        case stopped
        case failed
    }

    struct Notice {
        let title: String
        let message: String
        let offersSettings: Bool
        var unsavedSession: ScanSession? = nil
    }

    var onChange: (() -> Void)?
    private(set) var kind: ScanKind = .bluetooth
    private(set) var state: State = .idle
    private(set) var devices: [ScannedDevice] = []
    private(set) var progress: Double = 0
    private(set) var session: ScanSession?
    private var notices: [Notice] = []
    private let store: ScanSessionStore
    private let bluetoothScanner: DeviceScanning
    private let lanScanner: DeviceScanning
    private var scanner: DeviceScanning { kind == .bluetooth ? bluetoothScanner : lanScanner }

    var isBusy: Bool { state == .waiting || state == .scanning }

    init(scanner: DeviceScanning, lanScanner: DeviceScanning, store: ScanSessionStore) {
        self.store = store
        self.bluetoothScanner = scanner
        self.lanScanner = lanScanner
        scanner.onEvent = { [weak self] event in
            guard self?.kind == .bluetooth else { return }
            self?.handle(event)
        }
        lanScanner.onEvent = { [weak self] event in
            guard self?.kind == .lan else { return }
            self?.handle(event)
        }
    }

    func selectKind(_ kind: ScanKind) {
        guard !isBusy, self.kind != kind else { return }
        self.kind = kind
        devices = []
        progress = 0
        session = nil
        state = .idle
        onChange?()
    }

    private var scanDuration: ScanDuration = .standard

    func start(duration: ScanDuration) {
        guard !isBusy else { return }
        devices = []
        progress = 0
        session = nil
        scanDuration = duration
        state = .waiting
        onChange?()
        scanner.start(duration: TimeInterval(duration.rawValue))
    }

    func stop() {
        guard isBusy else { return }
        scanner.stop()
    }

    func takeNotice() -> Notice? {
        guard !notices.isEmpty else { return nil }
        return notices.removeFirst()
    }

    private func handle(_ event: ScanEvent) {
        guard isBusy else { return }
        switch event {
        case .waiting:
            state = .waiting
        case .started:
            state = .scanning
            session = ScanSession(kind: kind)
        case .discovered(var device):
            guard state == .scanning else { return }
            if let index = devices.firstIndex(where: { $0.id == device.id }) {
                device.name = device.name ?? devices[index].name
                devices[index] = device
            } else {
                devices.append(device)
            }
            session?.devices = devices
        case .progress(let value):
            guard state == .scanning else { return }
            progress = min(max(value, 0), 1)
        case .finished, .timedOut:
            progress = 1
            session?.finishedAt = Date()
            let count = devices.count
            let reachedTimeLimit: Bool
            if case .timedOut = event { reachedTimeLimit = true } else { reachedTimeLimit = false }
            state = reachedTimeLimit ? .timedOut : .finished
            notices.append(Notice(
                title: reachedTimeLimit ? "Time limit reached" : "Scan complete",
                message: "Found \(count) \(count == 1 ? "device" : "devices")."
                    + (reachedTimeLimit ? " The scan stopped after \(scanDuration.rawValue) seconds; some devices may not have responded yet." : ""),
                offersSettings: false
            ))
        case .cancelled:
            state = .stopped
            session?.finishedAt = Date()
        case .failed(let error):
            state = .failed
            session?.finishedAt = Date()
            notices.append(Notice(
                title: "Unable to scan",
                message: error.localizedDescription,
                offersSettings: error == .permissionDenied || error == .localNetworkDenied
            ))
        }
        if !isBusy, let session, session.finishedAt != nil {
            saveSession(session)
        }
        onChange?()
    }

    func saveSession(_ session: ScanSession) {
        store.save(session) { [weak self] result in
            guard let self else { return }
            if case .failure = result {
                self.notices.append(Notice(
                    title: "Scan not saved",
                    message: "The scan results could not be saved to history. You can retry saving them.",
                    offersSettings: false,
                    unsavedSession: session
                ))
                self.onChange?()
            }
        }
    }
}

enum ScanDuration: Int, CaseIterable {
    case short = 5
    case standard = 15
    case long = 30

    static var preferred: Self {
        get { Self(rawValue: UserDefaults.standard.integer(forKey: "scanDuration")) ?? .standard }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: "scanDuration") }
    }
}
