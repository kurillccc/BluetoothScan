//
//  ScanSessionViewController.swift
//  BluetoothScan
//
//  Created by Кирилл Чернов on 10.11.2026.
//

import UIKit

final class ScanSessionViewController: UITableViewController {
    private let session: ScanSession

    init(session: ScanSession) {
        self.session = session
        super.init(style: .insetGrouped)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = session.kind == .bluetooth ? "Bluetooth scan" : "LAN scan"
        navigationItem.largeTitleDisplayMode = .never
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 80
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        session.devices.count
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        DateFormatter.localizedString(from: session.startedAt, dateStyle: .medium, timeStyle: .short)
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        session.devices.isEmpty ? "No devices were found during this scan." : "\(session.devices.count) devices found"
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Device")
            ?? UITableViewCell(style: .subtitle, reuseIdentifier: "Device")
        let device = session.devices[indexPath.row]
        var content = cell.defaultContentConfiguration()
        content.text = device.name ?? "Unnamed device"
        switch device.address {
        case .bluetooth(let uuid): content.secondaryText = uuid.uuidString
        case .lan(let ip, _): content.secondaryText = ip
        }
        content.secondaryTextProperties.numberOfLines = 0
        content.secondaryTextProperties.color = .secondaryLabel
        cell.contentConfiguration = content
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        navigationController?.pushViewController(
            DeviceDetailsViewController(device: session.devices[indexPath.row]), animated: true
        )
    }
}
