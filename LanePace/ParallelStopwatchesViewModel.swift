//
//  ParallelStopwatchesViewModel.swift
//  LanePace
//
//  Created by AI on 21.08.25.
//

import Foundation
import SwiftData
import QuartzCore

@MainActor
final class ParallelStopwatchesViewModel: ObservableObject {
    struct Stopwatch: Equatable {
        var isRunning: Bool = false
        var elapsed: TimeInterval = 0
        var lastUptime: TimeInterval?
        var lapIndex: Int = 0
    }

    @Published private(set) var athleteIdToStopwatch: [PersistentIdentifier: Stopwatch] = [:]

    private var timer: DispatchSourceTimer?

    // MARK: - Public API
    func ensureStopwatch(for athleteId: PersistentIdentifier) {
        if athleteIdToStopwatch[athleteId] == nil {
            athleteIdToStopwatch[athleteId] = Stopwatch()
        }
    }

    func toggle(for athleteId: PersistentIdentifier) {
        ensureStopwatch(for: athleteId)
        var sw = athleteIdToStopwatch[athleteId]!
        if sw.isRunning {
            sw.isRunning = false
            sw.lastUptime = nil
            athleteIdToStopwatch[athleteId] = sw
            stopTimerIfNeeded()
        } else {
            sw.isRunning = true
            sw.lastUptime = CACurrentMediaTime()
            athleteIdToStopwatch[athleteId] = sw
            startTimerIfNeeded()
        }
    }

    func reset(for athleteId: PersistentIdentifier) {
        ensureStopwatch(for: athleteId)
        athleteIdToStopwatch[athleteId] = Stopwatch()
        stopTimerIfNeeded()
    }

    func addSplit(for athleteId: PersistentIdentifier) -> Int {
        ensureStopwatch(for: athleteId)
        var sw = athleteIdToStopwatch[athleteId]!
        sw.lapIndex += 1
        athleteIdToStopwatch[athleteId] = sw
        return sw.lapIndex
    }

    func elapsed(for athleteId: PersistentIdentifier) -> TimeInterval {
        athleteIdToStopwatch[athleteId]?.elapsed ?? 0
    }

    func lapIndex(for athleteId: PersistentIdentifier) -> Int {
        athleteIdToStopwatch[athleteId]?.lapIndex ?? 0
    }

    // MARK: - Timing
    private func startTimerIfNeeded() {
        guard timer == nil else { return }
        let t = DispatchSource.makeTimerSource(queue: DispatchQueue.main)
        t.schedule(deadline: .now(), repeating: .milliseconds(20), leeway: .milliseconds(2))
        t.setEventHandler { [weak self] in self?.tick() }
        timer = t
        t.resume()
    }

    private func stopTimerIfNeeded() {
        // Stop when nothing is running
        guard let timer, !athleteIdToStopwatch.values.contains(where: { $0.isRunning }) else { return }
        timer.setEventHandler {}
        timer.cancel()
        self.timer = nil
    }

    private func tick() {
        let now = CACurrentMediaTime()
        let runningIds = athleteIdToStopwatch
            .filter { $0.value.isRunning }
            .map { $0.key }

        guard !runningIds.isEmpty else { return }

        for id in runningIds {
            guard var sw = athleteIdToStopwatch[id] else { continue }
            let last = sw.lastUptime ?? now
            let delta = max(0, now - last)
            sw.lastUptime = now
            sw.elapsed += delta
            athleteIdToStopwatch[id] = sw
        }

        objectWillChange.send()
    }

    // MARK: - Formatting
    func format(_ interval: TimeInterval, showMillis: Bool = true) -> String {
        let totalMillis = Int((interval * 1000).rounded())
        let ms = totalMillis % 1000
        let totalSeconds = totalMillis / 1000
        let s = totalSeconds % 60
        let m = (totalSeconds / 60) % 60
        let h = totalSeconds / 3600
        if h > 0 {
            return showMillis ? String(format: "%d:%02d:%02d.%02d", h, m, s, ms/10) : String(format: "%d:%02d:%02d", h, m, s)
        } else {
            return showMillis ? String(format: "%d:%02d.%02d", m, s, ms/10) : String(format: "%d:%02d", m, s)
        }
    }
}





