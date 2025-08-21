//
//  TimerViewModel.swift
//  LanePace
//
//  Created by AI on 21.08.25.
//

import Foundation
import Combine
import QuartzCore

final class IntervalTimerViewModel: ObservableObject {
    enum Mode: String, CaseIterable, Identifiable { case stopwatch, intervals; var id: String { rawValue } }
    enum SegmentKind: String { case work, rest }

    struct IntervalStep: Identifiable, Equatable {
        let id = UUID()
        let kind: SegmentKind
        let duration: TimeInterval
        let label: String
    }

    // MARK: - Public, stopwatch
    @Published var mode: Mode = .stopwatch
    @Published private(set) var isRunning: Bool = false
    @Published private(set) var stopwatchElapsed: TimeInterval = 0

    // MARK: - Public, intervals
    @Published var steps: [IntervalStep] = []
    @Published var repeatTotal: Int = 1
    @Published private(set) var repeatIndex: Int = 0 // 0-based
    @Published private(set) var currentStepIndex: Int = 0
    @Published private(set) var currentStepElapsed: TimeInterval = 0
    @Published private(set) var totalElapsed: TimeInterval = 0

    // MARK: - Private timing
    private var timer: DispatchSourceTimer?
    private var tickQueue = DispatchQueue(label: "com.lanePace.timer", qos: .userInteractive)
    private var lastUptime: TimeInterval?

    // MARK: - Lifecycle
    init() {
        // Default simple program: 8 x (30s work / 10s rest)
        self.steps = [
            IntervalStep(kind: .work, duration: 30, label: "Work"),
            IntervalStep(kind: .rest, duration: 10, label: "Rest")
        ]
        self.repeatTotal = 8
    }

    deinit { stopTimer() }

    // MARK: - Public controls
    func start() {
        guard !isRunning else { return }
        isRunning = true
        lastUptime = CACurrentMediaTime()
        startTimer()
    }

    func pause() {
        guard isRunning else { return }
        isRunning = false
        lastUptime = nil
        stopTimer()
    }

    func reset() {
        isRunning = false
        lastUptime = nil
        stopTimer()
        stopwatchElapsed = 0
        currentStepElapsed = 0
        totalElapsed = 0
        currentStepIndex = 0
        repeatIndex = 0
    }

    func nextStep() {
        guard mode == .intervals else { return }
        advanceStep()
    }

    func previousStep() {
        guard mode == .intervals else { return }
        if currentStepElapsed > 0.5 {
            currentStepElapsed = 0
        } else if currentStepIndex > 0 {
            currentStepIndex -= 1
            currentStepElapsed = 0
        } else if repeatIndex > 0 {
            repeatIndex -= 1
            currentStepIndex = max(steps.count - 1, 0)
            currentStepElapsed = 0
        }
    }

    // MARK: - Private timing helpers
    private func startTimer() {
        if timer != nil { return }
        let t = DispatchSource.makeTimerSource(queue: tickQueue)
        // 50 Hz updates for smooth UI without being too heavy
        t.schedule(deadline: .now(), repeating: .milliseconds(20), leeway: .milliseconds(2))
        t.setEventHandler { [weak self] in self?.tick() }
        timer = t
        t.resume()
    }

    private func stopTimer() {
        timer?.setEventHandler {}
        timer?.cancel()
        timer = nil
    }

    private func tick() {
        guard isRunning, let last = lastUptime else { return }
        let now = CACurrentMediaTime()
        let delta = max(0, now - last)
        lastUptime = now

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            switch self.mode {
            case .stopwatch:
                self.stopwatchElapsed += delta
            case .intervals:
                self.totalElapsed += delta
                self.currentStepElapsed += delta
                self.evaluateStepBoundary()
            }
        }
    }

    private func evaluateStepBoundary() {
        guard mode == .intervals, !steps.isEmpty else { return }
        let current = steps[currentStepIndex]
        if currentStepElapsed >= current.duration - 0.000_5 {
            let overflow = currentStepElapsed - current.duration
            advanceStep()
            // carry over minimal overflow to avoid cumulative loss
            if overflow > 0 { currentStepElapsed += overflow }
        }
    }

    private func advanceStep() {
        currentStepElapsed = 0
        if currentStepIndex + 1 < steps.count {
            currentStepIndex += 1
            return
        }
        // Loop to next repeat
        if repeatIndex + 1 < repeatTotal {
            repeatIndex += 1
            currentStepIndex = 0
        } else {
            // Done
            isRunning = false
            lastUptime = nil
            stopTimer()
        }
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


