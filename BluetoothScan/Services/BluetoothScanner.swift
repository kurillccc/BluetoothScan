//
//  BluetoothScanner.swift
//  BluetoothScan
//
//  Created by Кирилл Чернов on 10.11.2026.
//

import CoreBluetooth
import Foundation

final class BluetoothScanner: NSObject, DeviceScanning {
    var onEvent: ((ScanEvent) -> Void)?

    private var central: CBCentralManager?
    private var timer: Timer?
    private var isRequested = false
    private var startedAt: TimeInterval?
    private var duration: TimeInterval = 15

    func start(duration: TimeInterval) {
        guard !isRequested else { return }
        self.duration = duration
        isRequested = true
        onEvent?(.waiting)
        if let central {
            handleState(central.state)
        } else {
            central = CBCentralManager(
                delegate: self,
                queue: .main,
                options: [CBCentralManagerOptionShowPowerAlertKey: false]
            )
        }
    }

    func stop() {
        guard isRequested else { return }
        finish(with: .cancelled)
    }

    private func handleState(_ state: CBManagerState) {
        guard isRequested else { return }
        switch state {
        case .poweredOn:
            beginScanning()
        case .poweredOff:
            finish(with: .failed(.bluetoothOff))
        case .unauthorized:
            finish(with: .failed(.permissionDenied))
        case .unsupported:
            finish(with: .failed(.unsupported))
        case .resetting:
            finish(with: .failed(.unavailable))
        case .unknown:
            if timer == nil {
                let timeout = Timer(timeInterval: duration, repeats: false) { [weak self] _ in
                    self?.finish(with: .failed(.unavailable))
                }
                timer = timeout
                RunLoop.main.add(timeout, forMode: .common)
            }
        @unknown default:
            finish(with: .failed(.unavailable))
        }
    }

    private func beginScanning() {
        guard startedAt == nil, let central else { return }
        timer?.invalidate()
        startedAt = ProcessInfo.processInfo.systemUptime
        central.scanForPeripherals(
            withServices: nil,
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: true]
        )
        onEvent?(.started)
        let timer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self, let startedAt = self.startedAt else { return }
            let elapsed = ProcessInfo.processInfo.systemUptime - startedAt
            self.onEvent?(.progress(min(elapsed / self.duration, 1)))
            if elapsed >= self.duration {
                self.finish(with: .finished)
            }
        }
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func finish(with event: ScanEvent) {
        guard isRequested else { return }
        isRequested = false
        timer?.invalidate()
        timer = nil
        if central?.state == .poweredOn, central?.isScanning == true {
            central?.stopScan()
        }
        startedAt = nil
        onEvent?(event)
    }

    deinit {
        timer?.invalidate()
        if central?.state == .poweredOn, central?.isScanning == true {
            central?.stopScan()
        }
    }
}

extension BluetoothScanner: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        handleState(central.state)
    }

    func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        guard isRequested, startedAt != nil else { return }
        let advertisedName = advertisementData[CBAdvertisementDataLocalNameKey] as? String
        let name = [advertisedName, peripheral.name]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }
        let status: ScannedDevice.ConnectionStatus
        switch peripheral.state {
        case .connected: status = .connected
        case .connecting: status = .connecting
        case .disconnecting: status = .disconnecting
        case .disconnected: status = .disconnected
        @unknown default: status = .disconnected
        }
        onEvent?(.discovered(ScannedDevice(
            address: .bluetooth(uuid: peripheral.identifier),
            name: name,
            rssi: RSSI.intValue == 127 ? nil : RSSI.intValue,
            connectionStatus: status
        )))
    }
}
