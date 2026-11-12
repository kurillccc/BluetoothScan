//
//  CoreDataScanSessionStore.swift
//  BluetoothScan
//
//  Created by Кирилл Чернов on 10.11.2026.
//

import CoreData
import Foundation

final class CoreDataScanSessionStore: ScanSessionStore {
    private enum StorageError: LocalizedError {
        case invalidRecord

        var errorDescription: String? { "A saved scan could not be read." }
    }

    private let storeURL: URL
    private let queue = DispatchQueue(label: "com.kurillccc.BluetoothScan.storage")
    private var context: NSManagedObjectContext?

    init(storeURL: URL = NSPersistentContainer.defaultDirectoryURL()
        .appendingPathComponent("BluetoothScan.sqlite")) {
        self.storeURL = storeURL
    }

    func save(_ session: ScanSession, completion: @escaping (Result<Void, Error>) -> Void) {
        perform({ context in
            let request = NSFetchRequest<NSManagedObject>(entityName: "StoredSession")
            request.predicate = NSPredicate(format: "id == %@", session.id as NSUUID)
            request.fetchLimit = 1
            let stored = try context.fetch(request).first
                ?? NSEntityDescription.insertNewObject(forEntityName: "StoredSession", into: context)
            stored.setValue(session.id, forKey: "id")
            stored.setValue(session.kind.rawValue, forKey: "kind")
            stored.setValue(session.startedAt, forKey: "startedAt")
            stored.setValue(session.finishedAt, forKey: "finishedAt")
            for device in stored.value(forKey: "devices") as? Set<NSManagedObject> ?? [] {
                context.delete(device)
            }
            for (index, device) in session.devices.enumerated() {
                let record = NSEntityDescription.insertNewObject(forEntityName: "StoredDevice", into: context)
                record.setValue(index, forKey: "position")
                record.setValue(device.name, forKey: "name")
                record.setValue(device.rssi, forKey: "rssi")
                record.setValue(device.connectionStatus?.rawValue, forKey: "connectionStatus")
                record.setValue(stored, forKey: "session")
                switch device.address {
                case .bluetooth(let uuid):
                    record.setValue(ScanKind.bluetooth.rawValue, forKey: "kind")
                    record.setValue(uuid, forKey: "uuid")
                case .lan(let ip, let mac):
                    record.setValue(ScanKind.lan.rawValue, forKey: "kind")
                    record.setValue(ip, forKey: "ip")
                    record.setValue(mac, forKey: "mac")
                }
            }
            try context.save()
        }, completion: completion)
    }

    func fetch(
        filter: ScanHistoryFilter,
        completion: @escaping (Result<[ScanSession], Error>) -> Void
    ) {
        perform({ context in
            let request = NSFetchRequest<NSManagedObject>(entityName: "StoredSession")
            var predicates: [NSPredicate] = []
            let name = filter.deviceName.trimmingCharacters(in: .whitespacesAndNewlines)
            if !name.isEmpty {
                predicates.append(NSPredicate(format: "ANY devices.name CONTAINS[cd] %@", name))
            }
            if let start = filter.startedAfter {
                predicates.append(NSPredicate(format: "startedAt >= %@", start as NSDate))
            }
            if let end = filter.startedBefore {
                predicates.append(NSPredicate(format: "startedAt < %@", end as NSDate))
            }
            request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
            request.sortDescriptors = [NSSortDescriptor(key: "startedAt", ascending: false)]
            request.relationshipKeyPathsForPrefetching = ["devices"]
            return try context.fetch(request).map(Self.decodeSession)
        }, completion: completion)
    }

    private func perform<Value>(
        _ operation: @escaping (NSManagedObjectContext) throws -> Value,
        completion: @escaping (Result<Value, Error>) -> Void
    ) {
        queue.async {
            let result: Result<Value, Error>
            do {
                let context = try self.loadContext()
                var operationResult: Result<Value, Error>!
                context.performAndWait {
                    operationResult = Result { try operation(context) }
                    if case .failure = operationResult { context.rollback() }
                }
                result = operationResult
            } catch {
                result = .failure(error)
            }
            DispatchQueue.main.async { completion(result) }
        }
    }

    private func loadContext() throws -> NSManagedObjectContext {
        if let context { return context }
        try FileManager.default.createDirectory(
            at: storeURL.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: ScanStorageModel.make())
        try coordinator.addPersistentStore(
            ofType: NSSQLiteStoreType, configurationName: nil, at: storeURL,
            options: [NSMigratePersistentStoresAutomaticallyOption: true,
                      NSInferMappingModelAutomaticallyOption: true]
        )
        let context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        context.persistentStoreCoordinator = coordinator
        self.context = context
        return context
    }

    private static func decodeSession(_ record: NSManagedObject) throws -> ScanSession {
        guard let id = record.value(forKey: "id") as? UUID,
              let rawKind = record.value(forKey: "kind") as? String,
              let kind = ScanKind(rawValue: rawKind),
              let startedAt = record.value(forKey: "startedAt") as? Date else {
            throw StorageError.invalidRecord
        }
        let devices = (record.value(forKey: "devices") as? Set<NSManagedObject> ?? [])
            .sorted { ($0.value(forKey: "position") as? Int ?? 0) < ($1.value(forKey: "position") as? Int ?? 0) }
        return ScanSession(
            id: id, kind: kind, startedAt: startedAt,
            finishedAt: record.value(forKey: "finishedAt") as? Date,
            devices: try devices.map(decodeDevice)
        )
    }

    private static func decodeDevice(_ record: NSManagedObject) throws -> ScannedDevice {
        let address: ScannedDevice.Address
        switch record.value(forKey: "kind") as? String {
        case ScanKind.bluetooth.rawValue:
            guard let uuid = record.value(forKey: "uuid") as? UUID else { throw StorageError.invalidRecord }
            address = .bluetooth(uuid: uuid)
        case ScanKind.lan.rawValue:
            guard let ip = record.value(forKey: "ip") as? String else { throw StorageError.invalidRecord }
            address = .lan(ip: ip, mac: record.value(forKey: "mac") as? String)
        default: throw StorageError.invalidRecord
        }
        return ScannedDevice(
            address: address, name: record.value(forKey: "name") as? String,
            rssi: record.value(forKey: "rssi") as? Int,
            connectionStatus: (record.value(forKey: "connectionStatus") as? String)
                .flatMap(ScannedDevice.ConnectionStatus.init(rawValue:))
        )
    }
}
