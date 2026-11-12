//
//  HistoryViewModel.swift
//  BluetoothScan
//
//  Created by Кирилл Чернов on 10.11.2026.
//

import Foundation

final class HistoryViewModel {
    enum Period: CaseIterable {
        case all, today, week, month

        var title: String {
            switch self {
            case .all: return "All dates"
            case .today: return "Today"
            case .week: return "Last 7 days"
            case .month: return "Last 30 days"
            }
        }
    }

    var onChange: (() -> Void)?
    private(set) var sessions: [ScanSession] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    private(set) var period: Period = .all
    private(set) var searchText = ""
    private let store: ScanSessionStore
    private let now: () -> Date
    private let calendar: Calendar
    private var requestID = 0

    var isFiltered: Bool {
        period != .all || !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    init(store: ScanSessionStore, now: @escaping () -> Date = Date.init, calendar: Calendar = .current) {
        self.store = store
        self.now = now
        self.calendar = calendar
    }

    func setSearchText(_ text: String) {
        guard searchText != text else { return }
        searchText = text
        reload()
    }

    func setPeriod(_ period: Period) {
        guard self.period != period else { return }
        self.period = period
        reload()
    }

    func reload() {
        requestID += 1
        let id = requestID
        isLoading = true
        errorMessage = nil
        onChange?()
        var filter = ScanHistoryFilter(deviceName: searchText)
        if period != .all {
            let today = calendar.startOfDay(for: now())
            let offset = period == .week ? -6 : period == .month ? -29 : 0
            filter.startedAfter = calendar.date(byAdding: .day, value: offset, to: today)
            filter.startedBefore = calendar.date(byAdding: .day, value: 1, to: today)
        }
        store.fetch(filter: filter) { [weak self] result in
            guard let self, self.requestID == id else { return }
            self.isLoading = false
            switch result {
            case .success(let sessions): self.sessions = sessions
            case .failure:
                self.sessions = []
                self.errorMessage = "Your scan history could not be loaded. Please try again."
            }
            self.onChange?()
        }
    }
}
