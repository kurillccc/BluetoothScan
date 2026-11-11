//
//  ScanSession.swift
//  BluetoothScan
//
//  Created by Кирилл Чернов on 10.11.2026.
//

import Foundation

struct ScanSession: Identifiable, Equatable, Codable {
    let id: UUID
    let kind: ScanKind
    let startedAt: Date
    var finishedAt: Date?
    var devices: [ScannedDevice]

    init(
        id: UUID = UUID(),
        kind: ScanKind,
        startedAt: Date = Date(),
        finishedAt: Date? = nil,
        devices: [ScannedDevice] = []
    ) {
        self.id = id
        self.kind = kind
        self.startedAt = startedAt
        self.finishedAt = finishedAt
        self.devices = devices
    }
}
