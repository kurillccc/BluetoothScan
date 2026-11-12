//
//  DeviceScanning.swift
//  BluetoothScan
//
//  Created by Кирилл Чернов on 10.11.2026.
//

import Foundation

enum ScanEvent {
    case waiting
    case started
    case discovered(ScannedDevice)
    case progress(Double)
    case finished
    case timedOut
    case cancelled
    case failed(ScanError)
}

enum ScanError: Error, LocalizedError {
    case bluetoothOff
    case permissionDenied
    case unsupported
    case unavailable
    case wifiUnavailable
    case localNetworkDenied
    case localNetworkUnavailable
    case networkChanged
    case unsupportedSubnet

    var errorDescription: String? {
        switch self {
        case .bluetoothOff: return "Turn on Bluetooth in Settings and try again."
        case .permissionDenied: return "Allow Bluetooth access for Bluetooth Scan in Settings."
        case .unsupported: return "Bluetooth scanning is not supported on this device."
        case .unavailable: return "Bluetooth is temporarily unavailable. Please try again."
        case .wifiUnavailable: return "Connect to a Wi-Fi network with an IPv4 address and try again."
        case .localNetworkDenied: return "Allow Local Network access for Bluetooth Scan in Settings."
        case .localNetworkUnavailable: return "The local network could not be reached. Check your Wi-Fi connection and try again."
        case .networkChanged: return "The Wi-Fi network changed during the scan. Start a new scan on the current network."
        case .unsupportedSubnet: return "This network's address range is not supported. Use an IPv4 network with 2 to 4094 host addresses."

        }
    }
}

protocol DeviceScanning: AnyObject {
    var onEvent: ((ScanEvent) -> Void)? { get set }
    func start()
    func stop()
}
