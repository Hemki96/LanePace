import SwiftUI
import SwiftData

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
                        if l == r {
                            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
                        }
                        return l < r
                    }

                ForEach(filtered) { athlete in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            TextField(
                                "Name",
                                text: Binding(
                                    get: { athlete.name },
                                    set: { athlete.name = $0 }
                                )
                            )
                            .textFieldStyle(.roundedBorder)
                            .disabled(athlete.isArchived)

                            Spacer()

                            Stepper(
                                value: Binding(
                                    get: { athlete.laneNumber ?? 1 },
                                    set: { athlete.laneNumber = $0 }
                                ),
                                in: 1...10
                            ) {
                                Text("Bahn: \(athlete.laneNumber ?? 1)")
                            }
                            .frame(maxWidth: 200)
                            .disabled(athlete.isArchived)
                        }

                        HStack {
                            Stepper(
                                value: Binding(
                                    get: { athlete.heatNumber ?? 1 },
                                    set: { athlete.heatNumber = $0 }
                                ),
                                in: 1...20
                            ) {
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
                        Button(role: .destructive) { modelContext.delete(athlete) } label: {
                            Label("Löschen", systemImage: "trash")
                        }
                        Button { athlete.isArchived.toggle() } label: {
                            Label(athlete.isArchived ? "Wiederherstellen" : "Archivieren", systemImage: "archivebox")
                        }
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
                        Label(
                            selectedHeat == nil ? "Alle Läufe" : "Lauf \(selectedHeat!)",
                            systemImage: "line.3.horizontal.decrease.circle"
                        )
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
