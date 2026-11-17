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
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .action, target: self, action: #selector(exportCSV)
        )
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tableView.reloadData()
    }

    @objc private func exportCSV() {
        let timestamp = ISO8601DateFormatter().string(from: session.startedAt)
        let kind = session.kind == .bluetooth ? "Bluetooth" : "LAN"
        var rows = [["Started at", "Scan type", "Name", "UUID", "IP", "MAC", "RSSI", "Status"]]
        if session.devices.isEmpty {
            rows.append([timestamp, kind, "", "", "", "", "", ""])
        }
        for device in session.devices {
            let name = spreadsheetName(device.displayName ?? "")
            switch device.address {
            case .bluetooth(let uuid):
                rows.append([
                    timestamp, kind, name, uuid.uuidString, "", "",
                    device.rssi.map { String($0) } ?? "", device.connectionStatus?.rawValue ?? ""
                ])
            case .lan(let ip, let mac):
                rows.append([timestamp, kind, name, "", ip, mac ?? "", "", ""])
            }
        }
        let csv = rows.map { row in
            row.map { "\"" + $0.replacingOccurrences(of: "\"", with: "\"\"") + "\"" }.joined(separator: ",")
        }.joined(separator: "\r\n") + "\r\n"

        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let filename = "BluetoothScan-" + timestamp.replacingOccurrences(of: ":", with: "-") + ".csv"
        let file = directory.appendingPathComponent(filename)
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try csv.write(to: file, atomically: true, encoding: .utf8)
            let share = UIActivityViewController(activityItems: [file], applicationActivities: nil)
            share.popoverPresentationController?.barButtonItem = navigationItem.rightBarButtonItem
            share.completionWithItemsHandler = { _, _, _, _ in
                try? FileManager.default.removeItem(at: directory)
            }
            present(share, animated: true)
        } catch {
            try? FileManager.default.removeItem(at: directory)
            let alert = UIAlertController(title: "Could not export scan", message: "Try again.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
        }
    }

    private func spreadsheetName(_ name: String) -> String {
        let first = name.trimmingCharacters(in: .whitespacesAndNewlines).first
        if let first, "=+-@".contains(first) { return "'" + name }
        return name
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
        cell.contentConfiguration = device.rowContent
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
