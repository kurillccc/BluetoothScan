//
//  DeviceDetailsViewController.swift
//  BluetoothScan
//
//  Created by Кирилл Чернов on 10.11.2026.
//

import UIKit

final class DeviceDetailsViewController: UITableViewController {
    private let viewModel: DeviceDetailsViewModel

    init(device: ScannedDevice) {
        viewModel = DeviceDetailsViewModel(device: device)
        super.init(style: .insetGrouped)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = viewModel.title
        navigationItem.largeTitleDisplayMode = .never
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 72
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
