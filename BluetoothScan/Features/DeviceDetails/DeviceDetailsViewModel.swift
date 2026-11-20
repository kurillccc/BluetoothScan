//
//  DeviceDetailsViewModel.swift
//  BluetoothScan
//
//  Created by Кирилл Чернов on 10.11.2026.
//

import Foundation

struct DeviceDetailsViewModel {
    struct Field {
        let title: String
        let value: String
    }

    let fields: [Field]

    init(device: ScannedDevice) {
        var fields = [Field(title: "Name", value: device.name ?? "Not available")]
        switch device.address {
        case .bluetooth(let uuid):
            fields.append(Field(title: "Type", value: "Bluetooth"))
            fields.append(Field(title: "UUID", value: uuid.uuidString))
            fields.append(Field(title: "RSSI", value: device.rssi.map { "\($0) dBm" } ?? "Not available"))
            let status: String
            switch device.connectionStatus {
            case .connected: status = "Connected"
            case .connecting: status = "Connecting"
            case .disconnected: status = "Disconnected"
            case .disconnecting: status = "Disconnecting"
            case nil: status = "Not available"
            }
            fields.append(Field(title: "Connection status", value: status))
        case .lan(let ip, let mac):
            fields.append(Field(title: "Type", value: "LAN"))
            fields.append(Field(title: "IP address", value: ip))
            fields.append(Field(title: "MAC address", value: mac ?? "Not available"))
        }
        self.fields = fields
    }
}
