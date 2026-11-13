//
//  ScanViewController.swift
//  BluetoothScan
//
//  Created by Кирилл Чернов on 10.11.2026.
//

import UIKit

final class ScanViewController: UIViewController {
    private let viewModel: ScanViewModel
    private let kindControl = UISegmentedControl(items: ["Bluetooth", "LAN"])
    private let scanButton = UIButton(type: .system)
    private let progressView = UIProgressView(progressViewStyle: .default)
    private let statusLabel = UILabel()
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let emptyStateView = EmptyStateView()
    private var displayedDevices: [ScannedDevice] = []
    private let kinds = ScanKind.allCases

    init(viewModel: ScanViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        configureLayout()
        viewModel.onChange = { [weak self] in self?.render() }
        NotificationCenter.default.addObserver(
            self, selector: #selector(enteredBackground),
            name: UIApplication.didEnterBackgroundNotification, object: nil
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(showNoticeIfNeeded),
            name: UIApplication.didBecomeActiveNotification, object: nil
        )
        render()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        showNoticeIfNeeded()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        viewModel.stop()
    }

    private func configureLayout() {
        kindControl.selectedSegmentIndex = 0
        kindControl.accessibilityLabel = "Scan type"
        kindControl.addTarget(self, action: #selector(scanKindChanged), for: .valueChanged)
        scanButton.configuration = .filled()
        scanButton.addTarget(self, action: #selector(scanTapped), for: .touchUpInside)
        statusLabel.font = .preferredFont(forTextStyle: .subheadline)
        statusLabel.adjustsFontForContentSizeCategory = true
        statusLabel.textColor = .secondaryLabel
        statusLabel.numberOfLines = 0
        progressView.accessibilityLabel = "Scan progress"

        let controls = UIStackView(arrangedSubviews: [kindControl, scanButton, statusLabel, progressView])
        controls.axis = .vertical
        controls.spacing = 12
        controls.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(controls)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 100
        tableView.tableFooterView = UIView()
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)

        let background = UIView()
        emptyStateView.translatesAutoresizingMaskIntoConstraints = false
        background.addSubview(emptyStateView)
        tableView.backgroundView = background
        NSLayoutConstraint.activate([
            controls.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            controls.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            controls.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
            tableView.topAnchor.constraint(equalTo: controls.bottomAnchor, constant: 16),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            emptyStateView.topAnchor.constraint(equalTo: background.topAnchor, constant: 24),
            emptyStateView.leadingAnchor.constraint(equalTo: background.leadingAnchor, constant: 24),
            emptyStateView.trailingAnchor.constraint(equalTo: background.trailingAnchor, constant: -24)
        ])
    }

    private func render() {
        kindControl.isEnabled = !viewModel.isBusy
        var configuration = scanButton.configuration
        configuration?.title = viewModel.isBusy ? "Stop scan" : "Scan for devices"
        configuration?.showsActivityIndicator = viewModel.isBusy
        scanButton.configuration = configuration
        progressView.isHidden = viewModel.state != .scanning
        progressView.setProgress(Float(viewModel.progress), animated: true)

        switch viewModel.state {
        case .idle:
            statusLabel.text = viewModel.kind == .bluetooth
                ? "Discover nearby Bluetooth LE devices in a 15-second scan."
                : "Find responding devices on your Wi-Fi network in a 15-second scan."
        case .waiting: statusLabel.text = viewModel.kind == .bluetooth
            ? "Waiting for Bluetooth…" : "Checking local network access…"
        case .scanning: statusLabel.text = "Scanning · \(viewModel.devices.count) found"
        case .finished: statusLabel.text = "Scan complete · \(viewModel.devices.count) found"
        case .timedOut: statusLabel.text = "Time limit reached · \(viewModel.devices.count) found"
        case .stopped: statusLabel.text = "Scan stopped · \(viewModel.devices.count) found"
        case .failed: statusLabel.text = "Scan interrupted. Check access and try again."
        }
        if displayedDevices != viewModel.devices {
            displayedDevices = viewModel.devices
            tableView.reloadData()
        }
        tableView.backgroundView?.isHidden = !displayedDevices.isEmpty
        tableView.separatorStyle = displayedDevices.isEmpty ? .none : .singleLine
        emptyStateView.configure(
            image: viewModel.kind == .bluetooth ? "antenna.radiowaves.left.and.right" : "wifi",
            title: viewModel.isBusy ? "Looking for devices" : "No devices found",
            message: viewModel.kind == .bluetooth
                ? "Keep nearby devices awake and advertising over Bluetooth."
                : "Connect to Wi-Fi. Devices that respond to discovery will appear here."
        )
        showNoticeIfNeeded()
    }

    @objc private func scanKindChanged() {
        viewModel.selectKind(kinds[kindControl.selectedSegmentIndex])
    }

    @objc private func scanTapped() {
        if viewModel.isBusy { viewModel.stop() } else { viewModel.start() }
    }

    @objc private func enteredBackground() {
        viewModel.stop()
    }

    @objc private func showNoticeIfNeeded() {
        guard isViewLoaded, view.window != nil,
              UIApplication.shared.applicationState == .active,
              presentedViewController == nil,
              let notice = viewModel.takeNotice() else { return }
        let alert = UIAlertController(title: notice.title, message: notice.message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .cancel) { [weak self, weak alert] _ in
            guard let alert else { return }
            self?.showNextNotice(after: alert)
        })
        if let session = notice.unsavedSession {
            alert.addAction(UIAlertAction(title: "Retry", style: .default) { [weak self, weak alert] _ in
                guard let alert else { return }
                self?.viewModel.saveSession(session)
                self?.showNextNotice(after: alert)
            })
        }
        if notice.offersSettings {
            alert.addAction(UIAlertAction(title: "Settings", style: .default) { _ in
                guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                UIApplication.shared.open(url)
            })
        }
        present(alert, animated: true)
    }

    private func showNextNotice(after alert: UIAlertController) {
        alert.dismiss(animated: true) { [weak self] in
            self?.showNoticeIfNeeded()
        }
    }
}

extension ScanViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        displayedDevices.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Device")
            ?? UITableViewCell(style: .subtitle, reuseIdentifier: "Device")
        let device = displayedDevices[indexPath.row]
        var content = cell.defaultContentConfiguration()
        content.text = device.name ?? "Unnamed device"
        switch device.address {
        case .bluetooth(let uuid):
            let signal = device.rssi.map { "\($0) dBm" } ?? "RSSI unavailable"
            let status = device.connectionStatus?.rawValue.capitalized ?? "Unknown status"
            content.secondaryText = "\(uuid.uuidString)\n\(signal) · \(status)"
        case .lan(let ip, let mac):
            content.secondaryText = "IP: \(ip)\nMAC: \(mac ?? "Not available")"
        }
        content.secondaryTextProperties.color = .secondaryLabel
        content.secondaryTextProperties.numberOfLines = 0
        cell.contentConfiguration = content
        cell.selectionStyle = .default
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let device = displayedDevices[indexPath.row]
        viewModel.stop()
        let details = DeviceDetailsViewController(device: device)
        navigationController?.pushViewController(details, animated: true)
    }

}
