//
//  ScanStorageModel.swift
//  BluetoothScan
//
//  Created by Кирилл Чернов on 10.11.2026.
//

import CoreData

enum ScanStorageModel {
    static func make() -> NSManagedObjectModel {
        let session = NSEntityDescription()
        session.name = "StoredSession"
        session.managedObjectClassName = "NSManagedObject"
        session.properties = [
            attribute("id", .UUIDAttributeType),
            attribute("kind", .stringAttributeType),
            attribute("startedAt", .dateAttributeType),
            attribute("finishedAt", .dateAttributeType, optional: true)
        ]
        session.uniquenessConstraints = [["id"]]

        let device = NSEntityDescription()
        device.name = "StoredDevice"
        device.managedObjectClassName = "NSManagedObject"
        device.properties = [
            attribute("position", .integer64AttributeType),
            attribute("kind", .stringAttributeType),
            attribute("uuid", .UUIDAttributeType, optional: true),
            attribute("ip", .stringAttributeType, optional: true),
            attribute("mac", .stringAttributeType, optional: true),
            attribute("name", .stringAttributeType, optional: true),
            attribute("rssi", .integer64AttributeType, optional: true),
            attribute("connectionStatus", .stringAttributeType, optional: true)
        ]
        let devices = NSRelationshipDescription()
        devices.name = "devices"
        devices.destinationEntity = device
        devices.minCount = 0
        devices.maxCount = 0
        devices.isOptional = true
        devices.deleteRule = .cascadeDeleteRule
        let owner = NSRelationshipDescription()
        owner.name = "session"
        owner.destinationEntity = session
        owner.minCount = 1
        owner.maxCount = 1
        owner.isOptional = false
        owner.deleteRule = .nullifyDeleteRule
        devices.inverseRelationship = owner
        owner.inverseRelationship = devices
        session.properties.append(devices)
        device.properties.append(owner)

        let model = NSManagedObjectModel()
        model.entities = [session, device]
        model.versionIdentifiers = ["1"]
        return model
    }

    private static func attribute(
        _ name: String,
        _ type: NSAttributeType,
        optional: Bool = false
    ) -> NSAttributeDescription {
        let attribute = NSAttributeDescription()
        attribute.name = name
        attribute.attributeType = type
        attribute.isOptional = optional
        return attribute
    }
}
