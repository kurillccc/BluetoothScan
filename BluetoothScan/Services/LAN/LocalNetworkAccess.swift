//
//  LocalNetworkAccess.swift
//  BluetoothScan
//
//  Created by Кирилл Чернов on 10.11.2026.
//

import Network
import UIKit

final class LocalNetworkAccess {
    private var browser: NWBrowser?
    private var listener: NWListener?
    private var timer: Timer?
    private var completion: ((Result<Void, ScanError>) -> Void)?
    private var deniedSince: TimeInterval?
    private var requestID = UUID()

    func request(completion: @escaping (Result<Void, ScanError>) -> Void) {
        cancel()
        self.completion = completion
        let id = requestID
        let serviceName = UUID().uuidString
        let parameters = NWParameters.tcp
        parameters.requiredInterfaceType = .wifi
        do {
            let listener = try NWListener(using: parameters)
            listener.service = NWListener.Service(name: serviceName, type: "_bluetoothscan._tcp")
            listener.newConnectionHandler = { $0.cancel() }
            listener.stateUpdateHandler = { [weak self] state in
                guard let self, self.requestID == id else { return }
                if case .failed = state { self.finish(.failure(.localNetworkUnavailable)) }
            }
            self.listener = listener
            let browser = NWBrowser(for: .bonjour(type: "_bluetoothscan._tcp", domain: "local."), using: parameters)
            browser.stateUpdateHandler = { [weak self] state in
                guard let self, self.requestID == id else { return }
                switch state {
                case .waiting(let error), .failed(let error):
                    if case .dns(let code) = error, code == -65570 {
                        self.deniedSince = ProcessInfo.processInfo.systemUptime
                    } else if case .failed = state {
                        self.finish(.failure(.localNetworkUnavailable))
                    }
                case .ready: self.deniedSince = nil
                default: break
                }
            }
            browser.browseResultsChangedHandler = { [weak self] results, _ in
                guard let self, self.requestID == id else { return }
                let found = results.contains { result in
                    if case .service(let name, _, _, _) = result.endpoint { return name == serviceName }
                    return false
                }
                if found { self.finish(.success(())) }
            }
            self.browser = browser
            let startedAt = ProcessInfo.processInfo.systemUptime
            let timer = Timer(timeInterval: 0.2, repeats: true) { [weak self] _ in
                guard let self, self.requestID == id else { return }
                let now = ProcessInfo.processInfo.systemUptime
                if let deniedSince = self.deniedSince, now - deniedSince > 1,
                   UIApplication.shared.applicationState == .active {
                    self.finish(.failure(.localNetworkDenied))
                } else if now - startedAt >= 30 {
                    self.finish(.failure(.localNetworkUnavailable))
                }
            }
            self.timer = timer
            RunLoop.main.add(timer, forMode: .common)
            listener.start(queue: .main)
            browser.start(queue: .main)
        } catch {
            finish(.failure(.localNetworkUnavailable))
        }
    }

    func cancel() {
        requestID = UUID()
        timer?.invalidate()
        timer = nil
        browser?.cancel()
        browser = nil
        listener?.cancel()
        listener = nil
        deniedSince = nil
        completion = nil
    }

    private func finish(_ result: Result<Void, ScanError>) {
        let callback = completion
        cancel()
        callback?(result)
    }

    deinit {
        timer?.invalidate()
        browser?.cancel()
        listener?.cancel()
    }
}
