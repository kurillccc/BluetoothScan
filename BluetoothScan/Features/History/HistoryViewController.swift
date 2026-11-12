//
//  HistoryViewController.swift
//  BluetoothScan
//
//  Created by Кирилл Чернов on 10.11.2026.
//

import UIKit

final class HistoryViewController: UITableViewController {
    private let viewModel: HistoryViewModel
    private let searchController = UISearchController(searchResultsController: nil)
    private let emptyStateView = EmptyStateView()
    private let activityIndicator = UIActivityIndicatorView(style: .medium)
    private let retryButton = UIButton(type: .system)
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    init(viewModel: HistoryViewModel) {
        self.viewModel = viewModel
        super.init(style: .insetGrouped)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        searchController.searchResultsUpdater = self
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.placeholder = "Device name"
        navigationItem.searchController = searchController
        navigationItem.hidesSearchBarWhenScrolling = false
        definesPresentationContext = true
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 80
        tableView.keyboardDismissMode = .onDrag
        refreshControl = UIRefreshControl()
        refreshControl?.addTarget(self, action: #selector(reloadHistory), for: .valueChanged)
        retryButton.setTitle("Try again", for: .normal)
        retryButton.addTarget(self, action: #selector(reloadHistory), for: .touchUpInside)
        activityIndicator.hidesWhenStopped = true
        let stack = UIStackView(arrangedSubviews: [activityIndicator, emptyStateView, retryButton])
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        let background = UIView()
        background.addSubview(stack)
        tableView.backgroundView = background
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: background.safeAreaLayoutGuide.topAnchor, constant: 32),
            stack.leadingAnchor.constraint(equalTo: background.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: background.trailingAnchor, constant: -24)
        ])
        viewModel.onChange = { [weak self] in self?.render() }
        NotificationCenter.default.addObserver(
            self, selector: #selector(reloadHistory), name: .scanHistoryDidChange, object: nil
        )
        updateDateMenu()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        viewModel.reload()
    }

    @objc private func reloadHistory() {
        viewModel.reload()
    }

    private func updateDateMenu() {
        let actions = HistoryViewModel.Period.allCases.map { period in
            UIAction(title: period.title, state: viewModel.period == period ? .on : .off) { [weak self] _ in
                self?.viewModel.setPeriod(period)
                self?.updateDateMenu()
            }
        }
        let button = UIBarButtonItem(
            title: viewModel.period.title,
            image: UIImage(systemName: "calendar"),
            primaryAction: nil,
            menu: UIMenu(title: "Scan date", children: actions)
        )
        button.accessibilityLabel = "Scan date: \(viewModel.period.title)"
        navigationItem.rightBarButtonItem = button
    }

    private func render() {
        if !viewModel.isLoading { refreshControl?.endRefreshing() }
        tableView.reloadData()
        tableView.backgroundView?.isHidden = !viewModel.sessions.isEmpty
        retryButton.isHidden = viewModel.errorMessage == nil
        emptyStateView.isHidden = viewModel.isLoading
        if viewModel.isLoading { activityIndicator.startAnimating() } else { activityIndicator.stopAnimating() }
        emptyStateView.configure(
            image: viewModel.errorMessage == nil ? "clock" : "exclamationmark.triangle",
            title: viewModel.errorMessage != nil ? "Unable to load history"
                : viewModel.isFiltered ? "No matching scans" : "No scans yet",
            message: viewModel.errorMessage ?? (viewModel.isFiltered
                ? "Try another device name or date range."
                : "Completed and stopped scans will appear here.")
        )
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        viewModel.sessions.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Session")
            ?? UITableViewCell(style: .subtitle, reuseIdentifier: "Session")
        let session = viewModel.sessions[indexPath.row]
        let kind = session.kind == .bluetooth ? "Bluetooth" : "LAN"
        var content = cell.defaultContentConfiguration()
        content.text = "\(kind) · \(dateFormatter.string(from: session.startedAt))"
        content.textProperties.numberOfLines = 0
        let count = session.devices.count
        content.secondaryText = "\(count) \(count == 1 ? "device" : "devices")"
        content.secondaryTextProperties.color = .secondaryLabel
        cell.contentConfiguration = content
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let controller = ScanSessionViewController(session: viewModel.sessions[indexPath.row])
        navigationController?.pushViewController(controller, animated: true)
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        guard !viewModel.sessions.isEmpty,
              !viewModel.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return "Scans containing a matching device. Open a scan to see all its devices."
    }
}

extension HistoryViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        viewModel.setSearchText(searchController.searchBar.text ?? "")
    }
}
