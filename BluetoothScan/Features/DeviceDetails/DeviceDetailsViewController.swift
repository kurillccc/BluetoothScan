//
//  DeviceDetailsViewController.swift
//  BluetoothScan
//
//  Created by Кирилл Чернов on 10.11.2026.
//

import UIKit

final class DeviceDetailsViewController: UITableViewController {
    private let device: ScannedDevice
    private let viewModel: DeviceDetailsViewModel

    init(device: ScannedDevice) {
        self.device = device
        viewModel = DeviceDetailsViewModel(device: device)
        super.init(style: .insetGrouped)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = device.displayTitle
        if case .bluetooth = device.address {
            navigationItem.rightBarButtonItem = UIBarButtonItem(
                title: "Rename", style: .plain, target: self, action: #selector(renameDevice)
            )
        }
        navigationItem.largeTitleDisplayMode = .never
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 72
    }

    @objc private func renameDevice() {
        let alert = UIAlertController(title: "Device name", message: "Leave blank to use the advertised name.", preferredStyle: .alert)
        alert.addTextField { $0.text = self.device.customName; $0.placeholder = self.device.name ?? "Custom name" }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Save", style: .default) { [weak self, weak alert] _ in
            guard let self, let name = alert?.textFields?.first?.text else { return }
            self.device.setCustomName(name)
            self.title = self.device.displayTitle
        })
        present(alert, animated: true)
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        viewModel.fields.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Field")
            ?? UITableViewCell(style: .subtitle, reuseIdentifier: "Field")
        let field = viewModel.fields[indexPath.row]
        var content = cell.defaultContentConfiguration()
        content.text = field.title
        content.secondaryText = field.value
        content.textProperties.numberOfLines = 0
        content.secondaryTextProperties.numberOfLines = 0
        content.secondaryTextProperties.color = .secondaryLabel
        cell.selectionStyle = .none
        cell.contentConfiguration = content
        return cell
    }

    override func tableView(
        _ tableView: UITableView,
        contextMenuConfigurationForRowAt indexPath: IndexPath,
        point: CGPoint
    ) -> UIContextMenuConfiguration? {
        let field = viewModel.fields[indexPath.row]
        guard field.value != "Not available" else { return nil }
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { _ in
            UIMenu(children: [
                UIAction(title: "Copy", image: UIImage(systemName: "doc.on.doc")) { _ in
                    UIPasteboard.general.string = field.value
                }
            ])
        }
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        "Values reflect the last discovery during this scan."
    }
}
