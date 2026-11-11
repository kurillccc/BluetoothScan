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
