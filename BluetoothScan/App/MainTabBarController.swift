//
//  MainTabBarController.swift
//  BluetoothScan
//
//  Created by Кирилл Чернов on 10.11.2026.
//

import UIKit

final class MainTabBarController: UITabBarController {
    override func viewDidLoad() {
        super.viewDidLoad()
        viewControllers = [
            makeNavigationController(
                root: ScanViewController(),
                title: "Scan",
                image: "antenna.radiowaves.left.and.right"
            ),
            makeNavigationController(
                root: HistoryViewController(),
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
