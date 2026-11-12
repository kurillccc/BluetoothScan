//
//  ScanSessionStore.swift
//  BluetoothScan
//
//  Created by Кирилл Чернов on 10.11.2026.
//

import Foundation

struct ScanHistoryFilter {
    var deviceName = ""
    var startedAfter: Date?
    var startedBefore: Date?
}

protocol ScanSessionStore: AnyObject {
    func save(_ session: ScanSession, completion: @escaping (Result<Void, Error>) -> Void)
    func fetch(
        filter: ScanHistoryFilter,
        completion: @escaping (Result<[ScanSession], Error>) -> Void
    )
}
