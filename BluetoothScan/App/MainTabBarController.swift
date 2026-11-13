//
//  MainTabBarController.swift
//  BluetoothScan
//
//  Created by Кирилл Чернов on 10.11.2026.
//

import UIKit

enum ScanAppearance {
    static let accent = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.37, green: 0.85, blue: 0.83, alpha: 1)
            : UIColor(red: 0.02, green: 0.38, blue: 0.42, alpha: 1)
    }

    static let actionBackground = UIColor(red: 0.02, green: 0.35, blue: 0.40, alpha: 1)
}

final class MainTabBarController: UITabBarController {
    private let sessionStore = CoreDataScanSessionStore()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.tintColor = ScanAppearance.accent
        viewControllers = [
            makeNavigationController(
                root: ScanViewController(viewModel: ScanViewModel(scanner: BluetoothScanner(), lanScanner: LANScanner(), store: sessionStore)),
                title: "Scan",
                image: "antenna.radiowaves.left.and.right"
            ),
            makeNavigationController(
                root: HistoryViewController(viewModel: HistoryViewModel(store: sessionStore)),
                title: "History",
                image: "clock"
            )
        ]
    }

    private func makeNavigationController(
        root: UIViewController,
        title: String,
        image: String
    ) -> UINavigationController {
        root.title = title
        let navigationController = UINavigationController(rootViewController: root)
        navigationController.navigationBar.prefersLargeTitles = true
        navigationController.tabBarItem = UITabBarItem(
            title: title,
            image: UIImage(systemName: image),
            selectedImage: nil
        )
        return navigationController
    }
}
