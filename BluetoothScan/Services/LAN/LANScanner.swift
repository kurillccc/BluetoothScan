//
//  LANScanner.swift
//  BluetoothScan
//
//  Created by Кирилл Чернов on 10.11.2026.
//

import Foundation

final class LANScanner: NSObject, DeviceScanning {
    var onEvent: ((ScanEvent) -> Void)?

    private let access = LocalNetworkAccess()
    private var scanner: MMLANScanner?
    private var timer: Timer?
    private var isRequested = false
    private var runID = UUID()
    private var network: WiFiNetwork?
    private var discoveryFinished = false
    private var resolvingNames = 0
    private var resolvedAddresses: Set<String> = []
    private let nameQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 4
        queue.qualityOfService = .utility
        return queue
    }()

    func start() {
        guard !isRequested else { return }
        isRequested = true
        runID = UUID()
        let id = runID
        onEvent?(.waiting)
        guard let network = WiFiNetwork.current() else {
            finish(.failed(.wifiUnavailable))
            return
        }
        guard network.supportsScanning else {
            finish(.failed(.unsupportedSubnet))
            return
        }
        self.network = network
        access.request { [weak self] result in
            guard let self, self.isRequested, self.runID == id else { return }
            switch result {
            case .success:
                guard WiFiNetwork.current() == network else {
                    self.finish(.failed(.networkChanged))
                    return
                }
                self.beginScanning()
            case .failure(let error): self.finish(.failed(error))
            }
        }
    }

    func stop() {
        guard isRequested else { return }
        finish(.cancelled)
    }

    private func beginScanning() {
        discoveryFinished = false
        resolvingNames = 0
        resolvedAddresses = []
        let startedAt = ProcessInfo.processInfo.systemUptime
        let timer = Timer(timeInterval: 0.2, repeats: true) { [weak self] _ in
            guard let self, self.isRequested else { return }
            guard WiFiNetwork.current() == self.network else {
                self.finish(.failed(.networkChanged))
                return
            }
            let elapsed = ProcessInfo.processInfo.systemUptime - startedAt
            self.onEvent?(.progress(min(elapsed / 15, 1)))
            if elapsed >= 15 { self.finish(.timedOut) }
        }
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
        scanner = MMLANScanner(delegate: self)
        onEvent?(.started)
        scanner?.start()
    }

    private func finish(_ event: ScanEvent) {
        guard isRequested else { return }
        isRequested = false
        runID = UUID()
        access.cancel()
        timer?.invalidate()
        timer = nil
        scanner?.delegate = nil
        scanner?.stop()
        scanner = nil
        nameQueue.cancelAllOperations()
        onEvent?(event)
    }

    private func resolveName(for device: ScannedDevice, address: String) {
        guard resolvedAddresses.insert(address).inserted else { return }
        resolvingNames += 1
        let id = runID
        nameQueue.addOperation { [weak self] in
            let name = LANProperties.getHostFromIPAddress(address)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            DispatchQueue.main.async { [weak self] in
                guard let self, self.isRequested, self.runID == id else { return }
                self.resolvingNames -= 1
                if let name, !name.isEmpty, name != address {
                    var updated = device
                    updated.name = name
                    self.onEvent?(.discovered(updated))
                }
                if self.discoveryFinished && self.resolvingNames == 0 { self.finish(.finished) }
            }
        }
    }

    deinit {
        timer?.invalidate()
        scanner?.delegate = nil
        scanner?.stop()
        nameQueue.cancelAllOperations()
    }
}

extension LANScanner: MMLANScannerDelegate {
    func lanScanDidFindNewDevice(_ device: MMDevice!) {
        guard isRequested, let device, let ip = device.ipAddress, !ip.isEmpty else { return }
        let name = device.hostname?.trimmingCharacters(in: .whitespacesAndNewlines)
        let result = ScannedDevice(
            address: .lan(ip: ip, mac: nil),
            name: name?.isEmpty == false ? name : nil,
            rssi: nil,
            connectionStatus: nil
        )
        onEvent?(.discovered(result))
        resolveName(for: result, address: ip)
    }

    func lanScanDidFinishScanning(with status: MMLanScannerStatus) {
        guard isRequested else { return }
        if status == MMLanScannerStatusCancelled {
            finish(.cancelled)
        } else {
            discoveryFinished = true
            if resolvingNames == 0 { finish(.finished) }
        }
    }

    func lanScanDidFailedToScan() {
        finish(.failed(.localNetworkUnavailable))
    }
}
