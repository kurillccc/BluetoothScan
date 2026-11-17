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
    func count(completion: @escaping (Result<Int, Error>) -> Void)
    func deleteAll(completion: @escaping (Result<Void, Error>) -> Void)
    func save(_ session: ScanSession, completion: @escaping (Result<Void, Error>) -> Void)
    func fetch(
        filter: ScanHistoryFilter,
        completion: @escaping (Result<[ScanSession], Error>) -> Void
    )
}

extension Notification.Name {
    static let scanHistoryDidChange = Notification.Name("scanHistoryDidChange")
}
