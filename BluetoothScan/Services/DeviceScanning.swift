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
    case cancelled
    case failed(ScanError)
}

enum ScanError: Error, LocalizedError {
    case bluetoothOff
    case permissionDenied
    case unsupported
    case unavailable

    var errorDescription: String? {
        switch self {
        case .bluetoothOff: return "Turn on Bluetooth in Settings and try again."
        case .permissionDenied: return "Allow Bluetooth access for Bluetooth Scan in Settings."
        case .unsupported: return "Bluetooth scanning is not supported on this device."
        case .unavailable: return "Bluetooth is temporarily unavailable. Please try again."
        }
    }
}

protocol DeviceScanning: AnyObject {
    var onEvent: ((ScanEvent) -> Void)? { get set }
    func start()
    func stop()
}
