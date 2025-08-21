//
//  ContentView.swift
//  LanePace
//
//  Created by Christian Hemker on 21.08.25.
//

import SwiftUI
import SwiftData

@Model
final class Athlete {
    var name: String
    var bibNumber: String?
    var laneNumber: Int?
    var heatNumber: Int?
    var notes: String?
    var isArchived: Bool

    init(name: String, bibNumber: String? = nil, laneNumber: Int? = nil, heatNumber: Int? = nil, notes: String? = nil, isArchived: Bool = false) {
        self.name = name
        self.bibNumber = bibNumber
        self.laneNumber = laneNumber
        self.heatNumber = heatNumber
        self.notes = notes
        self.isArchived = isArchived
    }
}

@Model
final class Split {
    var athlete: Athlete?
    var lapIndex: Int
    var elapsedMs: Int

    init(athlete: Athlete?, lapIndex: Int, elapsedMs: Int) {
        self.athlete = athlete
        self.lapIndex = lapIndex
        self.elapsedMs = elapsedMs
    }
}

@Model
final class Session {
    var date: Date
    var title: String
    var isCompetition: Bool
    var notes: String?
    var splits: [Split]

    init(date: Date = .now, title: String = "", isCompetition: Bool = false, notes: String? = nil, splits: [Split] = []) {
        self.date = date
        self.title = title
        self.isCompetition = isCompetition
        self.notes = notes
        self.splits = splits
    }
}

@Model
final class AppSettings {
    var iCloudSyncEnabled: Bool
    var currentMode: String // "training" or "competition"

    init(iCloudSyncEnabled: Bool = false) {
        self.iCloudSyncEnabled = iCloudSyncEnabled
        self.currentMode = "training"
    }
}

struct ContentView: View {
    var body: some View {
        TabView {
            ControlView()
                .tabItem {
                    Label("Control", systemImage: "stopwatch.fill")
                }
            AthletesView()
                .tabItem {
                    Label("Athletes", systemImage: "person.3.fill")
                }
            SessionsView()
                .tabItem {
                    Label("Sessions", systemImage: "calendar")
                }
            ParallelStopwatchesView()
                .tabItem {
                    Label("Stopwatches", systemImage: "rectangle.grid.2x2")
                }
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
        }
    }
}

struct ControlView: View {
    @EnvironmentObject var vm: IntervalTimerViewModel
    @StateObject private var advancedVM = AdvancedTimerViewModel()
    @Environment(\.modelContext) private var modelContext
    @Query private var settings: [AppSettings]
    @State private var showAdvancedTimer = false

    private var modeBinding: Binding<String> {
        Binding(
            get: { settings.first?.currentMode ?? "training" },
            set: { newValue in
                if let current = settings.first {
                    current.currentMode = newValue
                } else {
                    let created = AppSettings()
                    created.currentMode = newValue
                    modelContext.insert(created)
                }
            }
        )
    }

    private var header: some View {
        VStack(spacing: 16) {
            HStack {
                Button(showAdvancedTimer ? "Einfach" : "Erweitert") {
                    showAdvancedTimer.toggle()
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                if !showAdvancedTimer {
                    Picker("Modus", selection: $vm.mode) {
                        Text("Stoppuhr").tag(IntervalTimerViewModel.Mode.stopwatch)
                        Text("Intervalle").tag(IntervalTimerViewModel.Mode.intervals)
                    }
                    .pickerStyle(.segmented)
                }
            }
            
            HStack {
                Picker("Betriebsmodus", selection: modeBinding) {
                    Text("Training").tag("training")
                    Text("Wettkampf").tag("competition")
                }
                .pickerStyle(.segmented)
            }
        }
    }

    private var stopwatchView: some View {
        VStack(spacing: 16) {
            let isCompetition = (settings.first?.currentMode ?? "training") == "competition"
            
            Text(vm.format(vm.stopwatchElapsed))
                .font(.system(size: isCompetition ? 96 : 72, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(isCompetition ? .red : .primary)
            
            if isCompetition {
                Text("WETTKAMPF")
                    .font(.headline)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 4)
                    .background(.red.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            
            HStack(spacing: 24) {
                Button(vm.isRunning ? "Pause" : "Start") {
                    vm.isRunning ? vm.pause() : vm.start()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(isCompetition ? .large : .regular)

                Button("Reset") { vm.reset() }
                    .buttonStyle(.bordered)
                    .controlSize(isCompetition ? .large : .regular)
            }
        }
    }

    private var intervalsView: some View {
        VStack(spacing: 16) {
            let isCompetition = (settings.first?.currentMode ?? "training") == "competition"
            let step = vm.steps.isEmpty ? nil : vm.steps[vm.currentStepIndex]
            
            Text(step?.label ?? "Intervall")
                .font(.headline)
                .foregroundStyle(step?.kind == .work ? .primary : .secondary)

            Text(vm.format(vm.currentStepElapsed))
                .font(.system(size: isCompetition ? 80 : 60, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(isCompetition ? .red : .primary)

            Text("Gesamt: \(vm.format(vm.totalElapsed, showMillis: false))  •  Satz: \(vm.repeatIndex+1)/\(vm.repeatTotal)")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 16) {
                Button("◀︎") { vm.previousStep() }
                Button(vm.isRunning ? "Pause" : "Start") {
                    vm.isRunning ? vm.pause() : vm.start()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(isCompetition ? .large : .regular)
                Button("▶︎") { vm.nextStep() }
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Wiederholungen")
                    Spacer()
                    Stepper(value: $vm.repeatTotal, in: 1...50) {
                        Text("\(vm.repeatTotal)")
                    }
                    .frame(maxWidth: 160)
                }

                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(Array(vm.steps.enumerated()), id: \.offset) { idx, s in
                            let isCurrent = idx == vm.currentStepIndex
                            Text("\(s.kind == .work ? "Work" : "Rest") \(Int(s.duration))s")
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(isCurrent ? Color.accentColor.opacity(0.2) : Color.gray.opacity(0.15))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
            }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                header
                
                if showAdvancedTimer {
                    AdvancedTimerView(viewModel: advancedVM)
                } else {
                    Group {
                        switch vm.mode {
                        case .stopwatch: stopwatchView
                        case .intervals: intervalsView
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle(showAdvancedTimer ? "Erweiterte Timer" : "Steuerung")
        }
    }
}

struct AthletesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var athletes: [Athlete]
    @State private var showArchived: Bool = false
    @State private var selectedHeat: Int? = nil

    var body: some View {
        NavigationStack {
            List {
                let filtered = athletes
                    .filter { showArchived ? true : !$0.isArchived }
                    .filter { selectedHeat == nil ? true : $0.heatNumber == selectedHeat }
                    .sorted { lhs, rhs in
                        let l = lhs.laneNumber ?? Int.max
                        let r = rhs.laneNumber ?? Int.max
                        if l == r { return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending }
                        return l < r
                    }

                ForEach(filtered) { athlete in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            TextField("Name", text: Binding(
                                get: { athlete.name },
                                set: { athlete.name = $0 }
                            ))
                            .textFieldStyle(.roundedBorder)
                            .disabled(athlete.isArchived)

                            Spacer()

                            Stepper(value: Binding(
                                get: { athlete.laneNumber ?? 1 },
                                set: { athlete.laneNumber = $0 }
                            ), in: 1...10) {
                                Text("Bahn: \(athlete.laneNumber ?? 1)")
                            }
                            .frame(maxWidth: 200)
                            .disabled(athlete.isArchived)
                        }

                        HStack {
                            Stepper(value: Binding(
                                get: { athlete.heatNumber ?? 1 },
                                set: { athlete.heatNumber = $0 }
                            ), in: 1...20) {
                                Text("Lauf: \(athlete.heatNumber ?? 1)")
                            }
                            .frame(maxWidth: 180)

                            if let bib = Binding(
                                get: { athlete.bibNumber ?? "" },
                                set: { athlete.bibNumber = $0.isEmpty ? nil : $0 }
                            ) as Binding<String>? {
                                TextField("Startnr.", text: bib)
                                    .textFieldStyle(.roundedBorder)
                            }
                        }
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) { modelContext.delete(athlete) } label: { Label("Löschen", systemImage: "trash") }
                        Button { athlete.isArchived.toggle() } label: { Label(athlete.isArchived ? "Wiederherstellen" : "Archivieren", systemImage: "archivebox") }
                    }
                }
            }
            .navigationTitle("Athleten")
            .toolbar {
                ToolbarItemGroup(placement: .topBarLeading) {
                    Toggle("Archiv", isOn: $showArchived)
                    Menu {
                        Button("Alle Läufe") { selectedHeat = nil }
                        Divider()
                        let heats = Set(athletes.compactMap { $0.heatNumber }).sorted()
                        ForEach(heats, id: \.self) { heat in
                            Button("Lauf \(heat)") { selectedHeat = heat }
                        }
                    } label: {
                        Label(selectedHeat == nil ? "Alle Läufe" : "Lauf \(selectedHeat!)", systemImage: "line.3.horizontal.decrease.circle")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        let new = Athlete(name: "Neu")
                        modelContext.insert(new)
                    } label: {
                        Label("Neu", systemImage: "plus")
                    }
                }
            }
        }
    }
}

struct SessionsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Session.date, order: .reverse) private var sessions: [Session]

    var body: some View {
        NavigationStack {
            List {
                ForEach(sessions) { session in
                    NavigationLink {
                        SessionDetailView(session: session)
                    } label: {
                        VStack(alignment: .leading) {
                            Text(session.title.isEmpty ? session.date.formatted(date: .abbreviated, time: .shortened) : session.title)
                                .font(.headline)
                            if session.isCompetition {
                                Text("Wettkampf")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("Training")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        modelContext.delete(sessions[index])
                    }
                }
            }
            .navigationTitle("Einheiten")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        let new = Session(title: "")
                        modelContext.insert(new)
                    } label: {
                        Label("Neu", systemImage: "plus")
                    }
                }
            }
        }
    }
}

struct SessionDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var session: Session

    private var splitsByAthlete: [(Athlete?, [Split])] {
        let groups = Dictionary(grouping: session.splits, by: { $0.athlete })
        return groups.sorted { lhs, rhs in
            let lName = lhs.key?.name ?? "Unbekannt"
            let rName = rhs.key?.name ?? "Unbekannt"
            return lName.localizedCaseInsensitiveCompare(rName) == .orderedAscending
        }
    }

    var body: some View {
        List {
            Section("Details") {
                TextField("Titel", text: Binding(
                    get: { session.title },
                    set: { session.title = $0 }
                ))
                Toggle("Wettkampfmodus", isOn: Binding(
                    get: { session.isCompetition },
                    set: { session.isCompetition = $0 }
                ))
                Text(session.date.formatted(date: .complete, time: .shortened))
                    .foregroundStyle(.secondary)
            }

            ForEach(splitsByAthlete, id: \.0?.persistentModelID) { athlete, splits in
                Section(athlete?.name ?? "Unbekannt") {
                    ForEach(splits.sorted(by: { $0.lapIndex < $1.lapIndex })) { split in
                        HStack {
                            Text("Lap \(split.lapIndex)")
                            Spacer()
                            Text(formatMs(split.elapsedMs))
                                .monospacedDigit()
                        }
                    }

                    let times = splits.map { $0.elapsedMs }
                    if let min = times.min(), let avg = (times.isEmpty ? nil : times.reduce(0, +) / times.count) {
                        HStack {
                            Text("Best: \(formatMs(min))  •  Ø: \(formatMs(avg))")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                    }
                }
            }
        }
        .navigationTitle(session.title.isEmpty ? "Einheit" : session.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func formatMs(_ ms: Int) -> String {
        let totalSeconds = ms / 1000
        let centi = (ms % 1000) / 10
        let s = totalSeconds % 60
        let m = (totalSeconds / 60) % 60
        let h = totalSeconds / 3600
        if h > 0 { return String(format: "%d:%02d:%02d.%02d", h, m, s, centi) }
        return String(format: "%d:%02d.%02d", m, s, centi)
    }
}

struct ParallelStopwatchesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Athlete.laneNumber) private var athletes: [Athlete]
    @StateObject private var vm = ParallelStopwatchesViewModel()
    @Query(sort: \Session.date, order: .reverse) private var sessions: [Session]

    private var currentSession: Session {
        if let existing = sessions.first(where: { $0.date.formatted(date: .complete, time: .omitted) == Date().formatted(date: .complete, time: .omitted) }) {
            return existing
        }
        let s = Session(title: "", isCompetition: false)
        modelContext.insert(s)
        return s
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(athletes) { athlete in
                    HStack(spacing: 12) {
                        VStack(alignment: .leading) {
                            Text(athlete.name)
                                .font(.headline)
                            if let lane = athlete.laneNumber {
                                Text("Bahn \(lane)").font(.subheadline).foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Text(vm.format(vm.elapsed(for: athlete.persistentModelID)))
                            .font(.system(size: 20, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                        Button(vm.athleteIdToStopwatch[athlete.persistentModelID]?.isRunning == true ? "Pause" : "Start") {
                            vm.toggle(for: athlete.persistentModelID)
                        }
                        .buttonStyle(.borderedProminent)
                        Button("Split") {
                            let lap = vm.addSplit(for: athlete.persistentModelID)
                            let elapsedMs = Int((vm.elapsed(for: athlete.persistentModelID) * 1000).rounded())
                            let split = Split(athlete: athlete, lapIndex: lap, elapsedMs: elapsedMs)
                            currentSession.splits.append(split)
                        }
                        .buttonStyle(.bordered)
                        Button("Reset") {
                            vm.reset(for: athlete.persistentModelID)
                        }
                    }
                    .onAppear { vm.ensureStopwatch(for: athlete.persistentModelID) }
                }
            }
            .navigationTitle("Stopwatches")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        let a = Athlete(name: "Neu")
                        modelContext.insert(a)
                    } label: {
                        Label("Athlet", systemImage: "plus")
                    }
                }
            }
        }
    }
}

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var settings: [AppSettings]

    private var iCloudBinding: Binding<Bool> {
        Binding(
            get: { settings.first?.iCloudSyncEnabled ?? false },
            set: { newValue in
                if let current = settings.first {
                    current.iCloudSyncEnabled = newValue
                } else {
                    let created = AppSettings(iCloudSyncEnabled: newValue)
                    modelContext.insert(created)
                }
            }
        )
    }

    private var modeBinding: Binding<String> {
        Binding(
            get: { settings.first?.currentMode ?? "training" },
            set: { newValue in
                if let current = settings.first {
                    current.currentMode = newValue
                } else {
                    let created = AppSettings()
                    created.currentMode = newValue
                    modelContext.insert(created)
                }
            }
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Betriebsmodus") {
                    Picker("Standardmodus", selection: modeBinding) {
                        Text("Training").tag("training")
                        Text("Wettkampf").tag("competition")
                    }
                    .pickerStyle(.segmented)
                }
                
                Section("Synchronisation") {
                    Toggle("iCloud Sync aktivieren (optional)", isOn: iCloudBinding)
                }
            }
            .navigationTitle("Einstellungen")
            .onAppear {
                if settings.isEmpty {
                    modelContext.insert(AppSettings())
                }
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Athlete.self, Session.self, Split.self, AppSettings.self])
}
