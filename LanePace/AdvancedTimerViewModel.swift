//
//  AdvancedTimerViewModel.swift
//  LanePace
//
//  Created by AI on 21.08.25.
//

import Foundation
import Combine
import SwiftUI
import AVFoundation
import AudioToolbox
import UIKit

final class AdvancedTimerViewModel: ObservableObject {
    
    // MARK: - Timer Modes
    enum TimerMode: String, CaseIterable, Identifiable {
        case sendOff = "send_off"
        case countdown = "countdown" 
        case countUp = "count_up"
        case restBased = "rest_based"
        
        var id: String { rawValue }
        
        var displayName: String {
            switch self {
            case .sendOff: return "Send-off/Abgang"
            case .countdown: return "Countdown"
            case .countUp: return "Hochzählen"
            case .restBased: return "Rest-based"
            }
        }
    }
    
    // MARK: - Interval Series Types
    enum SeriesType: String, CaseIterable, Identifiable {
        case simple = "simple"
        case pyramid = "pyramid"
        case ladder = "ladder"
        case variable = "variable"
        
        var id: String { rawValue }
        
        var displayName: String {
            switch self {
            case .simple: return "Einfach"
            case .pyramid: return "Pyramide"
            case .ladder: return "Leiter"
            case .variable: return "Variabel"
            }
        }
    }
    
    // MARK: - Timer State
    enum TimerState {
        case stopped, running, paused, warning, finished
    }
    
    // MARK: - Lane Timer
    struct LaneTimer: Identifiable {
        let id = UUID()
        var name: String
        var laneNumber: Int
        var offset: TimeInterval = 0 // in seconds
        var currentTime: TimeInterval = 0
        var targetTime: TimeInterval = 0
        var state: TimerState = .stopped
        var isEnabled: Bool = true
        var volume: Float = 1.0 // 0.0 = mute, 1.0 = loud
        
        // Pace indicator
        var paceStatus: PaceStatus {
            guard targetTime > 0 else { return .neutral }
            let diff = currentTime - targetTime
            if abs(diff) <= 2.0 { return .onPace }
            return diff > 0 ? .behind : .ahead
        }
    }
    
    enum PaceStatus {
        case ahead, onPace, behind, neutral
        
        var color: Color {
            switch self {
            case .ahead: return .green
            case .onPace: return .yellow
            case .behind: return .red
            case .neutral: return .gray
            }
        }
    }
    
    // MARK: - Interval Definition
    struct IntervalSet: Identifiable {
        let id = UUID()
        var repetitions: Int
        var workTime: TimeInterval // in seconds
        var restTime: TimeInterval // in seconds
        var distance: String = ""
        var targetPace: String = "" // e.g., "1:05"
    }
    
    // MARK: - Published Properties
    @Published var currentTime = Date()
    @Published var use24HourFormat = true
    @Published var timerMode: TimerMode = .sendOff
    @Published var seriesType: SeriesType = .simple
    @Published var laneTimers: [LaneTimer] = []
    @Published var isRunning = false
    @Published var isPaused = false
    @Published var globalOffset: TimeInterval = 0
    
    // Interval Series
    @Published var intervalSets: [IntervalSet] = []
    @Published var currentSetIndex = 0
    @Published var currentRepetition = 0
    @Published var isInWorkPhase = true
    
    // Display Settings
    @Published var showCoachView = true
    @Published var preWarningTime: TimeInterval = 10.0
    @Published var enableHaptics = true
    @Published var enableAudio = true
    
    // MARK: - Private Properties
    private var timer: DispatchSourceTimer?
    private var audioPlayer: AVAudioPlayer?
    private let timeFormatter = DateFormatter()
    
    // MARK: - Initialization
    init() {
        setupTimeFormatter()
        setupDefaultLanes()
        startClockTimer()
        setupAudio()
    }
    
    deinit {
        timer?.cancel()
    }
    
    // MARK: - Setup Methods
    private func setupTimeFormatter() {
        timeFormatter.timeStyle = .medium
        updateTimeFormat()
    }
    
    private func updateTimeFormat() {
        timeFormatter.dateFormat = use24HourFormat ? "HH:mm:ss" : "h:mm:ss a"
    }
    
    private func setupDefaultLanes() {
        for i in 1...8 {
            laneTimers.append(LaneTimer(
                name: "Bahn \(i)",
                laneNumber: i
            ))
        }
    }
    
    private func startClockTimer() {
        timer = DispatchSource.makeTimerSource(queue: .main)
        timer?.schedule(deadline: .now(), repeating: .milliseconds(100))
        timer?.setEventHandler { [weak self] in
            self?.currentTime = Date()
            self?.updateTimers()
        }
        timer?.resume()
    }
    
    private func setupAudio() {
        // Setup audio session for timer sounds
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to setup audio session: \(error)")
        }
    }
    
    // MARK: - Timer Control Methods
    func startTimers() {
        isRunning = true
        isPaused = false
        
        for i in laneTimers.indices {
            if laneTimers[i].isEnabled {
                laneTimers[i].state = .running
            }
        }
        
        playSignal(.start)
        triggerImpactHaptic(.medium)
    }
    
    func pauseTimers() {
        isPaused = true
        
        for i in laneTimers.indices {
            if laneTimers[i].state == .running {
                laneTimers[i].state = .paused
            }
        }
        
        triggerImpactHaptic(.light)
    }
    
    func resumeTimers() {
        isPaused = false
        
        for i in laneTimers.indices {
            if laneTimers[i].state == .paused {
                laneTimers[i].state = .running
            }
        }
        
        triggerImpactHaptic(.light)
    }
    
    func resetTimers() {
        isRunning = false
        isPaused = false
        currentSetIndex = 0
        currentRepetition = 0
        isInWorkPhase = true
        
        for i in laneTimers.indices {
            laneTimers[i].currentTime = 0
            laneTimers[i].state = .stopped
        }
        
        triggerImpactHaptic(.heavy)
    }
    
    func addRepetition() {
        if currentSetIndex < intervalSets.count {
            let currentSet = intervalSets[currentSetIndex]
            if currentRepetition < currentSet.repetitions {
                currentRepetition += 1
                triggerImpactHaptic(.light)
            }
        }
    }
    
    func skipCurrentInterval() {
        if isInWorkPhase {
            isInWorkPhase = false
        } else {
            nextRepetition()
        }
        triggerImpactHaptic(.medium)
    }
    
    func restartCurrentRepetition() {
        isInWorkPhase = true
        
        for i in laneTimers.indices {
            laneTimers[i].currentTime = 0
        }
        
        triggerImpactHaptic(.medium)
    }
    
    // MARK: - Lane Management
    func addLane() {
        let newLaneNumber = (laneTimers.map { $0.laneNumber }.max() ?? 0) + 1
        laneTimers.append(LaneTimer(
            name: "Bahn \(newLaneNumber)",
            laneNumber: newLaneNumber
        ))
    }
    
    func removeLane(at index: Int) {
        guard index < laneTimers.count else { return }
        laneTimers.remove(at: index)
    }
    
    func updateLaneOffset(_ offset: TimeInterval, for laneIndex: Int) {
        guard laneIndex < laneTimers.count else { return }
        laneTimers[laneIndex].offset = offset
    }
    
    func toggleLane(_ laneIndex: Int) {
        guard laneIndex < laneTimers.count else { return }
        laneTimers[laneIndex].isEnabled.toggle()
    }
    
    // MARK: - Interval Series Management
    func addSimpleInterval(reps: Int, work: TimeInterval, rest: TimeInterval) {
        let interval = IntervalSet(
            repetitions: reps,
            workTime: work,
            restTime: rest
        )
        intervalSets.append(interval)
    }
    
    func createPyramidSeries(baseTime: TimeInterval, steps: Int) {
        intervalSets.removeAll()
        
        // Ascending
        for i in 1...steps {
            let workTime = baseTime * Double(i)
            intervalSets.append(IntervalSet(
                repetitions: 1,
                workTime: workTime,
                restTime: workTime * 0.5
            ))
        }
        
        // Descending
        for i in (1..<steps).reversed() {
            let workTime = baseTime * Double(i)
            intervalSets.append(IntervalSet(
                repetitions: 1,
                workTime: workTime,
                restTime: workTime * 0.5
            ))
        }
    }
    
    func createLadderSeries(startTime: TimeInterval, increment: TimeInterval, steps: Int) {
        intervalSets.removeAll()
        
        for i in 0..<steps {
            let workTime = startTime + (increment * Double(i))
            intervalSets.append(IntervalSet(
                repetitions: 1,
                workTime: workTime,
                restTime: workTime * 0.3
            ))
        }
    }
    
    // MARK: - Private Timer Update
    private func updateTimers() {
        guard isRunning && !isPaused else { return }
        
        let increment: TimeInterval = 0.1
        
        for i in laneTimers.indices {
            guard laneTimers[i].isEnabled && laneTimers[i].state == .running else { continue }
            
            switch timerMode {
            case .countUp:
                laneTimers[i].currentTime += increment
            case .countdown:
                laneTimers[i].currentTime = max(0, laneTimers[i].currentTime - increment)
                if laneTimers[i].currentTime <= 0 {
                    laneTimers[i].state = .finished
                    playSignal(.finish, for: i)
                }
            case .sendOff:
                laneTimers[i].currentTime += increment
                checkSendOffTiming(for: i)
            case .restBased:
                updateRestBasedTimer(for: i, increment: increment)
            }
            
            checkWarnings(for: i)
        }
    }
    
    private func checkSendOffTiming(for index: Int) {
        // Implement send-off logic based on interval series
        guard currentSetIndex < intervalSets.count else { return }
        let currentSet = intervalSets[currentSetIndex]
        
        let targetInterval = isInWorkPhase ? currentSet.workTime : currentSet.restTime
        
        if laneTimers[index].currentTime >= targetInterval {
            playSignal(.sendOff, for: index)
            // Move to next phase or repetition
            if isInWorkPhase {
                isInWorkPhase = false
                laneTimers[index].currentTime = 0
            } else {
                nextRepetition()
            }
        }
    }
    
    private func updateRestBasedTimer(for index: Int, increment: TimeInterval) {
        // Rest-based timing logic
        laneTimers[index].currentTime += increment
    }
    
    private func checkWarnings(for index: Int) {
        guard currentSetIndex < intervalSets.count else { return }
        let currentSet = intervalSets[currentSetIndex]
        let targetTime = isInWorkPhase ? currentSet.workTime : currentSet.restTime
        let timeRemaining = targetTime - laneTimers[index].currentTime
        
        if timeRemaining <= preWarningTime && timeRemaining > preWarningTime - 0.2 {
            laneTimers[index].state = .warning
            playSignal(.warning, for: index)
            triggerNotificationHaptic(.warning)
        }
    }
    
    private func nextRepetition() {
        currentRepetition += 1
        isInWorkPhase = true
        
        for i in laneTimers.indices {
            laneTimers[i].currentTime = 0
        }
        
        if currentSetIndex < intervalSets.count {
            let currentSet = intervalSets[currentSetIndex]
            if currentRepetition >= currentSet.repetitions {
                currentSetIndex += 1
                currentRepetition = 0
                
                if currentSetIndex >= intervalSets.count {
                    // Series finished
                    isRunning = false
                    playSignal(.seriesComplete)
                    triggerNotificationHaptic(.success)
                }
            }
        }
    }
    
    // MARK: - Audio/Visual Signals
    private enum SignalType {
        case start, warning, finish, sendOff, seriesComplete
    }
    
    private func playSignal(_ signal: SignalType, for laneIndex: Int? = nil) {
        guard enableAudio else { return }
        
        let volume = laneIndex.map { laneTimers[$0].volume } ?? 1.0
        guard volume > 0 else { return }
        
        // Play different sounds based on signal type
        // For now, use system sounds - in production you'd load custom audio files
        let systemSound: SystemSoundID
        switch signal {
        case .start: systemSound = 1057
        case .warning: systemSound = 1006
        case .finish: systemSound = 1005
        case .sendOff: systemSound = 1057
        case .seriesComplete: systemSound = 1005
        }
        
        AudioServicesPlaySystemSound(systemSound)
    }
    
    private func triggerNotificationHaptic(_ feedbackType: UINotificationFeedbackGenerator.FeedbackType) {
        guard enableHaptics else { return }
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(feedbackType)
    }
    
    private func triggerImpactHaptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        guard enableHaptics else { return }
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }
    
    // MARK: - Formatting Helpers
    func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        let centiseconds = Int((time.truncatingRemainder(dividingBy: 1)) * 100)
        return String(format: "%d:%02d.%02d", minutes, seconds, centiseconds)
    }
    
    func formatCurrentTime() -> String {
        updateTimeFormat()
        return timeFormatter.string(from: currentTime)
    }
    
    func formatTargetPace(_ paceString: String) -> TimeInterval {
        // Convert "1:05" format to seconds
        let components = paceString.split(separator: ":")
        guard components.count == 2,
              let minutes = Double(components[0]),
              let seconds = Double(components[1]) else {
            return 0
        }
        return minutes * 60 + seconds
    }
    
    // MARK: - View State
    func toggleTimeFormat() {
        use24HourFormat.toggle()
    }
    
    func toggleCoachView() {
        showCoachView.toggle()
    }
}
