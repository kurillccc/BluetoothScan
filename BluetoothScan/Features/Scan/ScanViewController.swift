//
//  ScanViewController.swift
//  BluetoothScan
//
//  Created by Кирилл Чернов on 10.11.2026.
//

import UIKit

final class ScanViewController: UIViewController {
    private let kindControl = UISegmentedControl(items: ["Bluetooth", "LAN"])
    private let emptyStateView = EmptyStateView()
    private let kinds = ScanKind.allCases

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        kindControl.selectedSegmentIndex = 0
        kindControl.accessibilityLabel = "Scan type"
        kindControl.addTarget(self, action: #selector(scanKindChanged), for: .valueChanged)

        let scrollView = UIScrollView()
        scrollView.alwaysBounceVertical = true
        let content = UIStackView(arrangedSubviews: [kindControl, emptyStateView])
        content.axis = .vertical
        content.spacing = 64
        content.isLayoutMarginsRelativeArrangement = true
        content.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 16, leading: 24, bottom: 32, trailing: 24)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        content.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        scrollView.addSubview(content)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            content.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            content.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            content.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            content.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor)
        ])
        scanKindChanged()
    }

    @objc private func scanKindChanged() {
        let kind = kinds[kindControl.selectedSegmentIndex]
        switch kind {
        case .bluetooth:
            emptyStateView.configure(
                image: "antenna.radiowaves.left.and.right",
                title: "No Bluetooth devices yet",
                message: "Nearby Bluetooth devices will appear here after a scan."
            )
        case .lan:
            emptyStateView.configure(
                image: "wifi",
                title: "No network devices yet",
                message: "Devices on your Wi-Fi network will appear here after a scan."
            )
        }
    }
}
