//
//  ScanViewController.swift
//  BluetoothScan
//
//  Created by Кирилл Чернов on 10.11.2026.
//

import UIKit
import Lottie

final class ScanViewController: UIViewController {
    private enum ResultSort: String {
        case name = "Name"
        case signal = "Signal strength"
        case ip = "IP address"
    }

    private var bluetoothSort: ResultSort = .signal
    private var lanSort: ResultSort = .ip
    private let viewModel: ScanViewModel
    private let kindControl = UISegmentedControl(items: ["Bluetooth", "LAN"])
    private let scanButton = UIButton(type: .system)
    private let progressView = UIProgressView(progressViewStyle: .default)
    private let modeLabel = UILabel()
    private let statusLabel = UILabel()
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let emptyStateView = EmptyStateView()
    private var displayedDevices: [ScannedDevice] = []
    private let hero = UIStackView()
    private let buttonHalo = UIView()
    private let scanAnimation = LottieAnimationView(name: "ScanRadar")
    private let resultsLabel = UILabel()
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
        view.backgroundColor = .systemGroupedBackground
        configureLayout()
        updateSortMenu()
        viewModel.onChange = { [weak self] in self?.render() }
        NotificationCenter.default.addObserver(
            self, selector: #selector(enteredBackground),
            name: UIApplication.didEnterBackgroundNotification, object: nil
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(showNoticeIfNeeded),
            name: UIApplication.didBecomeActiveNotification, object: nil
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(updateScanAnimation),
            name: UIAccessibility.reduceMotionStatusDidChangeNotification, object: nil
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

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let width = tableView.bounds.width
        guard width > 0 else { return }
        let height = hero.systemLayoutSizeFitting(
            CGSize(width: width, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required, verticalFittingPriority: .fittingSizeLevel
        ).height
        if hero.frame.size != CGSize(width: width, height: height) {
            hero.frame = CGRect(x: 0, y: 0, width: width, height: height)
            tableView.tableHeaderView = hero
        }
        let footerHeight = emptyStateView.systemLayoutSizeFitting(
            CGSize(width: max(1, width - 48), height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required, verticalFittingPriority: .fittingSizeLevel
        ).height + 48
        if let footer = tableView.tableFooterView, !footer.isHidden,
           footer.frame.size != CGSize(width: width, height: footerHeight) {
            footer.frame.size = CGSize(width: width, height: footerHeight)
            tableView.tableFooterView = footer
        }
    }

    private func configureLayout() {
        navigationItem.largeTitleDisplayMode = .never
        kindControl.selectedSegmentIndex = 0
        kindControl.accessibilityLabel = "Scan type"
        kindControl.addTarget(self, action: #selector(scanKindChanged), for: .valueChanged)
        var configuration = UIButton.Configuration.filled()
        configuration.baseBackgroundColor = ScanAppearance.actionBackground
        configuration.baseForegroundColor = .white
        configuration.background.cornerRadius = 92
        configuration.cornerStyle = .fixed
        configuration.imagePlacement = .top
        configuration.imagePadding = 12
        configuration.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 42, weight: .light)
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var result = attributes
            result.font = UIFont.systemFont(ofSize: 22, weight: .semibold)
            return result
        }
        scanButton.configuration = configuration
        scanButton.layer.shadowColor = ScanAppearance.actionBackground.cgColor
        scanButton.layer.shadowOpacity = 0.22
        scanButton.layer.shadowRadius = 18
        scanButton.layer.shadowOffset = CGSize(width: 0, height: 10)
        scanButton.addTarget(self, action: #selector(scanTapped), for: .touchUpInside)

        let radar = UIView()
        buttonHalo.backgroundColor = ScanAppearance.accent.withAlphaComponent(0.07)
        buttonHalo.layer.cornerRadius = 118
        buttonHalo.layer.borderWidth = 1
        buttonHalo.layer.borderColor = ScanAppearance.accent.withAlphaComponent(0.13).cgColor
        buttonHalo.isUserInteractionEnabled = false
        let innerRing = UIView()
        innerRing.isUserInteractionEnabled = false
        innerRing.layer.cornerRadius = 104
        innerRing.layer.borderWidth = 1
        innerRing.layer.borderColor = ScanAppearance.accent.withAlphaComponent(0.18).cgColor
        for (element, size) in [(buttonHalo, CGFloat(236)), (innerRing, CGFloat(208)), (scanButton, CGFloat(184))] {
            element.translatesAutoresizingMaskIntoConstraints = false
            radar.addSubview(element)
            NSLayoutConstraint.activate([
                element.centerXAnchor.constraint(equalTo: radar.centerXAnchor),
                element.centerYAnchor.constraint(equalTo: radar.centerYAnchor),
                element.widthAnchor.constraint(equalToConstant: size),
                element.heightAnchor.constraint(equalToConstant: size)
            ])
        }
        scanAnimation.contentMode = .scaleAspectFit
        scanAnimation.loopMode = .loop
        scanAnimation.backgroundBehavior = .pauseAndRestore
        scanAnimation.isUserInteractionEnabled = false
        scanAnimation.isAccessibilityElement = false
        scanAnimation.translatesAutoresizingMaskIntoConstraints = false
        radar.insertSubview(scanAnimation, belowSubview: scanButton)
        NSLayoutConstraint.activate([
            scanAnimation.centerXAnchor.constraint(equalTo: radar.centerXAnchor),
            scanAnimation.centerYAnchor.constraint(equalTo: radar.centerYAnchor),
            scanAnimation.widthAnchor.constraint(equalToConstant: 264),
            scanAnimation.heightAnchor.constraint(equalToConstant: 264)
        ])
        radar.heightAnchor.constraint(equalToConstant: 264).isActive = true
        modeLabel.font = .preferredFont(forTextStyle: .title2)
        modeLabel.adjustsFontForContentSizeCategory = true
        modeLabel.numberOfLines = 0
        modeLabel.textAlignment = .center
        modeLabel.accessibilityTraits.insert(.header)
        statusLabel.font = .preferredFont(forTextStyle: .subheadline)
        statusLabel.adjustsFontForContentSizeCategory = true
        statusLabel.textColor = .secondaryLabel
        statusLabel.numberOfLines = 0
        statusLabel.textAlignment = .center
        progressView.progressTintColor = ScanAppearance.accent
        progressView.accessibilityLabel = "Scan progress"
        resultsLabel.font = .preferredFont(forTextStyle: .headline)
        resultsLabel.adjustsFontForContentSizeCategory = true
        resultsLabel.numberOfLines = 0
        resultsLabel.accessibilityTraits.insert(.header)

        hero.axis = .vertical
        hero.spacing = 12
        hero.isLayoutMarginsRelativeArrangement = true
        hero.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 16, leading: 24, bottom: 8, trailing: 24)
        [kindControl, radar, modeLabel, statusLabel, progressView, resultsLabel].forEach(hero.addArrangedSubview)
        hero.setCustomSpacing(28, after: statusLabel)
        hero.setCustomSpacing(24, after: progressView)
        tableView.backgroundColor = .clear
        tableView.contentInsetAdjustmentBehavior = .always
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 100
        tableView.tableHeaderView = hero
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)
        let footer = UIView()
        emptyStateView.translatesAutoresizingMaskIntoConstraints = false
        footer.addSubview(emptyStateView)
        tableView.tableFooterView = footer
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            emptyStateView.topAnchor.constraint(equalTo: footer.topAnchor, constant: 24),
            emptyStateView.leadingAnchor.constraint(equalTo: footer.leadingAnchor, constant: 24),
            emptyStateView.trailingAnchor.constraint(equalTo: footer.trailingAnchor, constant: -24)
        ])
    }

    @objc private func updateScanAnimation() {
        let shouldAnimate = viewModel.isBusy && !UIAccessibility.isReduceMotionEnabled
        scanAnimation.isHidden = !shouldAnimate
        if shouldAnimate {
            if !scanAnimation.isAnimationPlaying { scanAnimation.play() }
        } else {
            scanAnimation.stop()
        }
    }

    private func render() {
        kindControl.isEnabled = !viewModel.isBusy
        modeLabel.text = viewModel.kind == .bluetooth ? "Nearby Bluetooth" : "Local network"
        var configuration = scanButton.configuration
        configuration?.image = UIImage(systemName: viewModel.isBusy ? "stop.fill" : "dot.radiowaves.left.and.right")
        configuration?.title = viewModel.isBusy ? "Stop" : "Scan"
        configuration?.showsActivityIndicator = false
        scanButton.accessibilityLabel = viewModel.isBusy ? "Stop scan" : "Scan for devices"
        updateScanAnimation()
        resultsLabel.text = "Devices · \(viewModel.devices.count)"
        scanButton.configuration = configuration
        progressView.isHidden = viewModel.state != .scanning
        progressView.setProgress(Float(viewModel.progress), animated: true)

        switch viewModel.state {
        case .idle:
            statusLabel.text = viewModel.kind == .bluetooth
                ? "Discover nearby Bluetooth LE devices in a \(ScanDuration.preferred.rawValue)-second scan."
                : "Find responding devices on your Wi-Fi network in a \(ScanDuration.preferred.rawValue)-second scan."
        case .waiting: statusLabel.text = viewModel.kind == .bluetooth
            ? "Waiting for Bluetooth…" : "Checking local network access…"
        case .scanning: statusLabel.text = "Scanning · \(viewModel.devices.count) found"
        case .finished: statusLabel.text = "Scan complete · \(viewModel.devices.count) found"
        case .timedOut: statusLabel.text = "Time limit reached · \(viewModel.devices.count) found"
        case .stopped: statusLabel.text = "Scan stopped · \(viewModel.devices.count) found"
        case .failed: statusLabel.text = "Scan interrupted. Check access and try again."
        }
        let results = orderedResults()
        if displayedDevices != results {
            displayedDevices = results
            tableView.reloadData()
        }
        tableView.tableFooterView?.isHidden = !displayedDevices.isEmpty
        if !displayedDevices.isEmpty {
            tableView.tableFooterView?.frame.size.height = 0
        }
        view.setNeedsLayout()
        tableView.separatorStyle = displayedDevices.isEmpty ? .none : .singleLine
        emptyStateView.configure(
            image: viewModel.kind == .bluetooth ? "antenna.radiowaves.left.and.right" : "wifi",
            title: viewModel.isBusy ? "Looking for devices" : (viewModel.state == .idle ? "Ready to discover" : "No devices found"),
            message: viewModel.kind == .bluetooth
                ? "Keep nearby devices awake and advertising over Bluetooth."
                : "Connect to Wi-Fi. Devices that respond to discovery will appear here."
        )
        showNoticeIfNeeded()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tableView.reloadData()
        render()
    }

    @objc private func openSettings() {
        navigationController?.pushViewController(ScanSettingsViewController(store: viewModel.store), animated: true)
    }

    private var selectedSort: ResultSort {
        viewModel.kind == .bluetooth ? bluetoothSort : lanSort
    }

    private func updateSortMenu() {
        let options: [ResultSort] = [.name, viewModel.kind == .bluetooth ? .signal : .ip]
        let actions = options.map { option in
            UIAction(title: option.rawValue, state: option == selectedSort ? .on : .off) { [weak self] _ in
                guard let self else { return }
                if self.viewModel.kind == .bluetooth {
                    self.bluetoothSort = option
                } else {
                    self.lanSort = option
                }
                self.updateSortMenu()
                self.render()
            }
        }
        let item = UIBarButtonItem(
            title: nil,
            image: UIImage(systemName: "arrow.up.arrow.down"),
            primaryAction: nil,
            menu: UIMenu(title: "Sort after scanning", children: actions)
        )
        item.accessibilityLabel = "Sort results"
        navigationItem.rightBarButtonItems = [
            UIBarButtonItem(
                image: UIImage(systemName: "gearshape"),
                style: .plain, target: self, action: #selector(openSettings)
            ),
            item
        ]
        navigationItem.rightBarButtonItems?.first?.accessibilityLabel = "Settings"
    }

    private func orderedResults() -> [ScannedDevice] {
        let devices = viewModel.devices
        guard !viewModel.isBusy else { return devices }

        switch selectedSort {
        case .name:
            return devices.sorted { first, second in
                guard let firstName = first.displayName else { return false }
                guard let secondName = second.displayName else { return true }
                return firstName.localizedStandardCompare(secondName) == .orderedAscending
            }
        case .signal:
            return devices.sorted { ($0.rssi ?? Int.min) > ($1.rssi ?? Int.min) }
        case .ip:
            return devices.sorted { first, second in
                guard case .lan(let firstIP, _) = first.address,
                      case .lan(let secondIP, _) = second.address else { return false }
                return firstIP.compare(secondIP, options: .numeric) == .orderedAscending
            }
        }
    }

    @objc private func scanKindChanged() {
        viewModel.selectKind(kinds[kindControl.selectedSegmentIndex])
        updateSortMenu()
    }

    @objc private func scanTapped() {
        if viewModel.isBusy { viewModel.stop() } else { viewModel.start(duration: .preferred) }
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
        cell.contentConfiguration = device.rowContent
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

extension ScannedDevice {
    var rowContent: UIListContentConfiguration {
        var content = UIListContentConfiguration.subtitleCell()
        content.text = displayTitle
        content.textProperties.numberOfLines = 0
        content.secondaryTextProperties.numberOfLines = 0
        content.secondaryTextProperties.color = .secondaryLabel
        content.imageProperties.tintColor = ScanAppearance.accent
        content.imageProperties.reservedLayoutSize = CGSize(width: 32, height: 32)
        switch address {
        case .bluetooth:
            content.image = UIImage(systemName: "antenna.radiowaves.left.and.right")
            let signal = rssi.map { "\($0) dBm" } ?? "Signal unavailable"
            let status = connectionStatus?.rawValue.capitalized ?? "Unknown status"
            content.secondaryText = "\(status) · \(signal)"
        case .lan(let ip, _):
            content.image = UIImage(systemName: "wifi")
            content.secondaryText = displayName == nil ? "Hostname unavailable" : "IP: \(ip)"
        }
        return content
    }
}

private final class ScanSettingsViewController: UITableViewController {
    private let store: ScanSessionStore
    private var sessionCount: Int?
    private var isClearing = false

    init(store: ScanSessionStore) {
        self.store = store
        super.init(style: .insetGrouped)
        title = "Settings"
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshCount()
    }

    private func refreshCount() {
        store.count { [weak self] result in
            self?.sessionCount = try? result.get()
            self?.tableView.reloadData()
        }
    }

    private func confirmClearHistory() {
        guard !isClearing, (sessionCount ?? 0) > 0 else { return }
        let alert = UIAlertController(title: "Clear scan history?", message: "All saved scans will be deleted.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Delete All", style: .destructive) { [weak self] _ in
            guard let self else { return }
            self.isClearing = true
            self.store.deleteAll { [weak self] result in
                guard let self else { return }
                self.isClearing = false
                self.refreshCount()
                if case .failure = result {
                    let error = UIAlertController(title: "Could not clear history", message: "Try again.", preferredStyle: .alert)
                    error.addAction(UIAlertAction(title: "OK", style: .default))
                    self.present(error, animated: true)
                }
            }
        })
        present(alert, animated: true)
    }

    override func numberOfSections(in tableView: UITableView) -> Int { 3 }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        section == 0 ? ScanDuration.allCases.count : 1
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        ["Scan duration", "Permissions", "History"][section]
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        guard section < 2 else { return nil }
        return section == 0
            ? "Applies to the next Bluetooth or LAN scan."
            : "Manage Bluetooth and Local Network access in iOS Settings."
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Setting")
            ?? UITableViewCell(style: .default, reuseIdentifier: "Setting")
        var content = cell.defaultContentConfiguration()
        if indexPath.section == 0 {
            let duration = ScanDuration.allCases[indexPath.row]
            content.text = "\(duration.rawValue) seconds"
            cell.accessoryType = duration == .preferred ? .checkmark : .none
        } else if indexPath.section == 2 {
            content.text = "Clear history"
            content.secondaryText = sessionCount.map { "\($0) saved scans" }
            content.textProperties.color = (sessionCount ?? 0) > 0 ? .systemRed : .secondaryLabel
            cell.accessoryType = .none
        } else {
            content.text = "Open iOS Settings"
            cell.accessoryType = .disclosureIndicator
        }
        cell.contentConfiguration = content
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if indexPath.section == 0 {
            ScanDuration.preferred = ScanDuration.allCases[indexPath.row]
            tableView.reloadSections(IndexSet(integer: 0), with: .none)
        } else if indexPath.section == 2 {
            confirmClearHistory()
        } else if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}
