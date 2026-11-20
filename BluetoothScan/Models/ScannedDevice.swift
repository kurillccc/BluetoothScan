//
//  ScannedDevice.swift
//  BluetoothScan
//
//  Created by Кирилл Чернов on 10.11.2026.
//

import Foundation

struct ScannedDevice: Identifiable, Equatable, Codable {
    enum ConnectionStatus: String, Codable {
        case disconnected
        case connecting
        case connected
        case disconnecting
    }

    enum Address: Equatable, Codable {
        case bluetooth(uuid: UUID)
        case lan(ip: String, mac: String?)
    }

    let address: Address
    var name: String?
    var rssi: Int?
    var connectionStatus: ConnectionStatus?

    var id: String {
        switch address {
        case .bluetooth(let uuid):
            return "bluetooth:\(uuid.uuidString)"
        case .lan(let ip, _):
            return "lan:\(ip)"
        }
    }
}

extension ScannedDevice {
    var displayName: String? { customName ?? name }

    var displayTitle: String {
        if let displayName { return displayName }
        switch address {
        case .bluetooth(let uuid):
            return "Bluetooth device · " + String(uuid.uuidString.prefix(8))
        case .lan(let ip, _):
            return ip
        }
    }

    var customName: String? {
        guard let key = customNameKey else { return nil }
        return UserDefaults.standard.string(forKey: key)
    }

    func setCustomName(_ value: String) {
        guard let key = customNameKey else { return }
        let name = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if name.isEmpty {
            UserDefaults.standard.removeObject(forKey: key)
        } else {
            UserDefaults.standard.set(name, forKey: key)
        }
    }

    private var customNameKey: String? {
        guard case .bluetooth(let uuid) = address else { return nil }
        return "bluetoothAlias." + uuid.uuidString
    }
}
