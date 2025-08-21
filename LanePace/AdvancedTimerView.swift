//
//  AdvancedTimerView.swift
//  LanePace
//
//  Created by AI on 21.08.25.
//

import SwiftUI

struct AdvancedTimerView: View {
    @ObservedObject var viewModel: AdvancedTimerViewModel
    @State private var showSetupSheet = false
    @State private var showDisplayView = false
    @State private var showKeyboardHelp = false
    
    var body: some View {
        if viewModel.showCoachView {
            coachView
                .onKeyPress(.space) {
                    if viewModel.isRunning {
                        if viewModel.isPaused {
                            viewModel.resumeTimers()
                        } else {
                            viewModel.pauseTimers()
                        }
                    } else {
                        viewModel.startTimers()
                    }
                    return .handled
                }
                .onKeyPress(.return) {
                    if viewModel.isRunning {
                        if viewModel.isPaused {
                            viewModel.resumeTimers()
                        } else {
                            viewModel.pauseTimers()
                        }
                    } else {
                        viewModel.startTimers()
                    }
                    return .handled
                }
                .onKeyPress("r") {
                    viewModel.resetTimers()
                    return .handled
                }
                .onKeyPress("+") {
                    viewModel.addRepetition()
                    return .handled
                }
                .onKeyPress("s") {
                    viewModel.skipCurrentInterval()
                    return .handled
                }
                .onKeyPress("t") {
                    viewModel.restartCurrentRepetition()
                    return .handled
                }
                .onKeyPress("c") {
                    viewModel.toggleCoachView()
                    return .handled
                }
                .onKeyPress("h") {
                    viewModel.toggleTimeFormat()
                    return .handled
                }
                .onKeyPress("?") {
                    showKeyboardHelp.toggle()
                    return .handled
                }
        } else {
            displayView
                .onKeyPress(.escape) {
                    viewModel.toggleCoachView()
                    return .handled
                }
                .onKeyPress(.space) {
                    if viewModel.isRunning {
                        if viewModel.isPaused {
                            viewModel.resumeTimers()
                        } else {
                            viewModel.pauseTimers()
                        }
                    } else {
                        viewModel.startTimers()
                    }
                    return .handled
                }
        }
    }
    
    // MARK: - Coach View (Full Control Interface)
    private var coachView: some View {
        VStack(spacing: 20) {
            // Large Clock Display
            clockDisplay
            
            // Timer Mode Selection
            modeSelector
            
            // Lane Timers Grid
            laneTimersGrid
            
            // Control Buttons
            controlButtons
            
            // Series Information
            if !viewModel.intervalSets.isEmpty {
                seriesInfo
            }
        }
        .sheet(isPresented: $showSetupSheet) {
            IntervalSetupView(viewModel: viewModel)
        }
        .sheet(isPresented: $showDisplayView) {
            DisplayView(viewModel: viewModel)
        }
        .sheet(isPresented: $showKeyboardHelp) {
            KeyboardHelpView()
        }
    }
    
    // MARK: - Display View (Fullscreen Timer Display)
    private var displayView: some View {
        DisplayView(viewModel: viewModel)
    }
    
    // MARK: - Clock Display
    private var clockDisplay: some View {
        VStack(spacing: 8) {
            Text(viewModel.formatCurrentTime())
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .monospacedDigit()
            
            Button(viewModel.use24HourFormat ? "24h" : "12h") {
                viewModel.toggleTimeFormat()
            }
            .font(.caption)
            .buttonStyle(.bordered)
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Mode Selector
    private var modeSelector: some View {
        VStack(spacing: 12) {
            Picker("Timer Modus", selection: $viewModel.timerMode) {
                ForEach(AdvancedTimerViewModel.TimerMode.allCases) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            
            HStack {
                Picker("Serie Typ", selection: $viewModel.seriesType) {
                    ForEach(AdvancedTimerViewModel.SeriesType.allCases) { type in
                        Text(type.displayName).tag(type)
                    }
                }
                .pickerStyle(.menu)
                
                Spacer()
                
                Button("Setup") {
                    showSetupSheet = true
                }
                .buttonStyle(.bordered)
                
                Button("Display") {
                    showDisplayView = true
                }
                .buttonStyle(.bordered)
                
                Button("?") {
                    showKeyboardHelp = true
                }
                .buttonStyle(.bordered)
                .help("Keyboard Shortcuts")
            }
        }
    }
    
    // MARK: - Lane Timers Grid
    private var laneTimersGrid: some View {
        ScrollView {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 2), spacing: 12) {
                ForEach(Array(viewModel.laneTimers.enumerated()), id: \.offset) { index, laneTimer in
                    LaneTimerCard(
                        laneTimer: laneTimer,
                        onToggle: { viewModel.toggleLane(index) },
                        onOffsetChange: { offset in viewModel.updateLaneOffset(offset, for: index) }
                    )
                }
            }
            .padding()
        }
    }
    
    // MARK: - Control Buttons
    private var controlButtons: some View {
        VStack(spacing: 12) {
            // Primary Controls
            HStack(spacing: 16) {
                Button(viewModel.isRunning ? "Stop" : "Start") {
                    if viewModel.isRunning {
                        viewModel.resetTimers()
                    } else {
                        viewModel.startTimers()
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                
                Button(viewModel.isPaused ? "Resume" : "Pause") {
                    if viewModel.isPaused {
                        viewModel.resumeTimers()
                    } else {
                        viewModel.pauseTimers()
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .disabled(!viewModel.isRunning)
            }
            
            // Secondary Controls
            HStack(spacing: 12) {
                Button("+1 Rep") {
                    viewModel.addRepetition()
                }
                .buttonStyle(.bordered)
                
                Button("Skip") {
                    viewModel.skipCurrentInterval()
                }
                .buttonStyle(.bordered)
                
                Button("Restart Rep") {
                    viewModel.restartCurrentRepetition()
                }
                .buttonStyle(.bordered)
                
                Button("Reset") {
                    viewModel.resetTimers()
                }
                .buttonStyle(.bordered)
                .foregroundStyle(.red)
            }
        }
    }
    
    // MARK: - Series Information
    private var seriesInfo: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Serie Status")
                    .font(.headline)
                Spacer()
                Text("Set \(viewModel.currentSetIndex + 1)/\(viewModel.intervalSets.count)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            if viewModel.currentSetIndex < viewModel.intervalSets.count {
                let currentSet = viewModel.intervalSets[viewModel.currentSetIndex]
                HStack {
                    Text("Rep \(viewModel.currentRepetition + 1)/\(currentSet.repetitions)")
                    Spacer()
                    Text(viewModel.isInWorkPhase ? "Arbeit" : "Pause")
                        .foregroundStyle(viewModel.isInWorkPhase ? .green : .orange)
                }
                .font(.subheadline)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Lane Timer Card
struct LaneTimerCard: View {
    let laneTimer: AdvancedTimerViewModel.LaneTimer
    let onToggle: () -> Void
    let onOffsetChange: (TimeInterval) -> Void
    
    @State private var showOffsetPicker = false
    
    var body: some View {
        VStack(spacing: 8) {
            // Header
            HStack {
                Text(laneTimer.name)
                    .font(.headline)
                Spacer()
                Button {
                    onToggle()
                } label: {
                    Image(systemName: laneTimer.isEnabled ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(laneTimer.isEnabled ? .green : .gray)
                }
            }
            
            // Time Display
            Text(formatTime(laneTimer.currentTime))
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(laneTimer.isEnabled ? .primary : .secondary)
            
            // Pace Indicator
            HStack {
                Circle()
                    .fill(laneTimer.paceStatus.color)
                    .frame(width: 12, height: 12)
                
                Text(paceStatusText(laneTimer.paceStatus))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                // Offset Display
                if laneTimer.offset != 0 {
                    Text("\(laneTimer.offset > 0 ? "+" : "")\(Int(laneTimer.offset))s")
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
            }
            
            // Volume Control
            HStack {
                Image(systemName: laneTimer.volume > 0 ? "speaker.2.fill" : "speaker.slash.fill")
                    .font(.caption)
                Slider(value: .constant(laneTimer.volume), in: 0...1)
                    .disabled(true) // For display only in this simplified version
            }
            .font(.caption)
        }
        .padding()
        .background(laneTimer.isEnabled ? Color(.systemBackground) : Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(laneTimer.state == .warning ? Color.orange : Color.clear, lineWidth: 2)
        )
        .contextMenu {
            Button("Offset +5s") { onOffsetChange(laneTimer.offset + 5) }
            Button("Offset +10s") { onOffsetChange(laneTimer.offset + 10) }
            Button("Reset Offset") { onOffsetChange(0) }
            Button("Offset -5s") { onOffsetChange(laneTimer.offset - 5) }
            Button("Offset -10s") { onOffsetChange(laneTimer.offset - 10) }
        }
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        let centiseconds = Int((time.truncatingRemainder(dividingBy: 1)) * 100)
        return String(format: "%d:%02d.%02d", minutes, seconds, centiseconds)
    }
    
    private func paceStatusText(_ status: AdvancedTimerViewModel.PaceStatus) -> String {
        switch status {
        case .ahead: return "Vor"
        case .onPace: return "Ziel"
        case .behind: return "Nach"
        case .neutral: return "—"
        }
    }
}

// MARK: - Display View (Fullscreen)
struct DisplayView: View {
    @ObservedObject var viewModel: AdvancedTimerViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 40) {
                // Large Clock
                Text(viewModel.formatCurrentTime())
                    .font(.system(size: 80, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                
                // Active Timers Display
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 20) {
                    ForEach(viewModel.laneTimers.filter { $0.isEnabled }) { timer in
                        VStack(spacing: 8) {
                            Text(timer.name)
                                .font(.title2)
                                .foregroundStyle(.white)
                            
                            Text(formatTime(timer.currentTime))
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundStyle(timer.state == .warning ? .orange : .white)
                                .monospacedDigit()
                            
                            // Pace indicator
                            Circle()
                                .fill(timer.paceStatus.color)
                                .frame(width: 16, height: 16)
                        }
                        .padding()
                        .background(Color.white.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                
                Spacer()
            }
            .padding(40)
            
            // Close button
            VStack {
                HStack {
                    Spacer()
                    Button("Schließen") {
                        dismiss()
                    }
                    .foregroundStyle(.white)
                    .padding()
                }
                Spacer()
            }
        }
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        let centiseconds = Int((time.truncatingRemainder(dividingBy: 1)) * 100)
        return String(format: "%d:%02d.%02d", minutes, seconds, centiseconds)
    }
}

// MARK: - Interval Setup View
struct IntervalSetupView: View {
    @ObservedObject var viewModel: AdvancedTimerViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var repetitions = 10
    @State private var workMinutes = 1
    @State private var workSeconds = 5
    @State private var restMinutes = 0
    @State private var restSeconds = 30
    @State private var distance = "100m"
    @State private var targetPace = "1:05"
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Intervall Einstellungen") {
                    Stepper("Wiederholungen: \(repetitions)", value: $repetitions, in: 1...50)
                    
                    HStack {
                        Text("Arbeitszeit")
                        Spacer()
                        Picker("Minuten", selection: $workMinutes) {
                            ForEach(0..<10, id: \.self) { Text("\($0)").tag($0) }
                        }
                        .pickerStyle(.wheel)
                        .frame(width: 60)
                        Text(":")
                        Picker("Sekunden", selection: $workSeconds) {
                            ForEach(0..<60, id: \.self) { Text(String(format: "%02d", $0)).tag($0) }
                        }
                        .pickerStyle(.wheel)
                        .frame(width: 80)
                    }
                    
                    HStack {
                        Text("Pausenzeit")
                        Spacer()
                        Picker("Minuten", selection: $restMinutes) {
                            ForEach(0..<10, id: \.self) { Text("\($0)").tag($0) }
                        }
                        .pickerStyle(.wheel)
                        .frame(width: 60)
                        Text(":")
                        Picker("Sekunden", selection: $restSeconds) {
                            ForEach(0..<60, id: \.self) { Text(String(format: "%02d", $0)).tag($0) }
                        }
                        .pickerStyle(.wheel)
                        .frame(width: 80)
                    }
                    
                    TextField("Distanz", text: $distance)
                    TextField("Zielzeit (z.B. 1:05)", text: $targetPace)
                }
                
                Section("Vordefinierte Serien") {
                    Button("Pyramide (30s - 5min)") {
                        viewModel.createPyramidSeries(baseTime: 30, steps: 10)
                        dismiss()
                    }
                    
                    Button("Leiter (1min + 30s pro Stufe)") {
                        viewModel.createLadderSeries(startTime: 60, increment: 30, steps: 8)
                        dismiss()
                    }
                }
            }
            .navigationTitle("Intervall Setup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Hinzufügen") {
                        let workTime = TimeInterval(workMinutes * 60 + workSeconds)
                        let restTime = TimeInterval(restMinutes * 60 + restSeconds)
                        viewModel.addSimpleInterval(reps: repetitions, work: workTime, rest: restTime)
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Keyboard Help View
struct KeyboardHelpView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                Section("Timer Controls") {
                    HelpRow(key: "Space / Enter", description: "Start/Pause/Resume timer")
                    HelpRow(key: "R", description: "Reset all timers")
                    HelpRow(key: "+", description: "Add one repetition")
                    HelpRow(key: "S", description: "Skip current interval")
                    HelpRow(key: "T", description: "Restart current repetition")
                }
                
                Section("View Controls") {
                    HelpRow(key: "C", description: "Toggle Coach/Display view")
                    HelpRow(key: "H", description: "Toggle 12h/24h time format")
                    HelpRow(key: "Escape", description: "Exit fullscreen display")
                    HelpRow(key: "?", description: "Show keyboard shortcuts")
                }
                
                Section("Lane Controls") {
                    HelpRow(key: "Context Menu", description: "Right-click lane cards for offset controls (+5s, +10s, reset)")
                }
            }
            .navigationTitle("Keyboard Shortcuts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct HelpRow: View {
    let key: String
    let description: String
    
    var body: some View {
        HStack {
            Text(key)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 100, alignment: .leading)
            
            Text(description)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

#Preview {
    AdvancedTimerView(viewModel: AdvancedTimerViewModel())
}
