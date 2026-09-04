import SwiftUI

struct VisitListView: View {
    @State private var model: VisitListViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(model: VisitListViewModel) {
        _model = State(initialValue: model)
    }

    var body: some View {
        @Bindable var model = model

        return NavigationStack {
            content
                // Loading → loaded shouldn't snap; the states cross-fade.
                .animatedChange(model.state.id, reduceMotion: reduceMotion)
                .navigationTitle("Visits")
                // The mock schedule isn't today, so state the day rather than assume it.
                .navigationSubtitle(model.scheduleDay)
                .searchable(text: $model.filter.search, prompt: "Pet, owner, or address")
                .refreshable { await model.refresh() }
                .navigationDestination(for: String.self) {
                    VisitDetailView(model: VisitDetailViewModel(visitID: $0, store: model))
                }
        }
        .task { await model.load() }
    }

    @ViewBuilder
    private var content: some View {
        switch model.state {
        case .loaded:
            list

        case .loading:
            VisitListSkeleton()

        case .empty:
            ContentUnavailableView("No visits today", systemImage: "calendar.badge.checkmark",
                                   description: Text("When the office assigns you a visit, it'll show up here."))

        // Only a cold failure takes the screen; a stale cache warns inline instead.
        case .failed(let error):
            ContentUnavailableView {
                Label("Couldn't load your visits", systemImage: "wifi.exclamationmark")
            } description: {
                Text(error.localizedDescription)
            } actions: {
                Button("Try Again") { Task { await model.refresh() } }.buttonStyle(.borderedProminent)
            }
        }
    }

    private var list: some View {
        List {
            if let error = model.loadError as? NetworkError {
                Label(error.hint, systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote).foregroundStyle(.orange)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }

            Section {
                ForEach(model.filtered) { visit in
                    NavigationLink(value: visit.id) { VisitRow(visit: visit) }
                        .cardRow()
                }
            } header: {
                FilterChips(selection: $model.filter.status, count: model.count, has: model.has)
                    .textCase(nil)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }

            if model.filtered.isEmpty {
                // Distinct from "no visits today": there are visits, the filter hides
                // them. Collapsing the two would say the schedule failed to load.
                ContentUnavailableView {
                    Label("No matching visits", systemImage: "line.3.horizontal.decrease.circle")
                } actions: {
                    Button("Clear Filters") { model.filter = VisitFilter() }
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color(.systemGroupedBackground))
        .animatedChange(model.filtered.map(\.id), reduceMotion: reduceMotion)
    }
}

/// Status chips with counts taken from the unfiltered set.
private struct FilterChips: View {
    @Binding var selection: VisitStatus?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let count: (VisitStatus?) -> Int
    let has: (VisitStatus) -> Bool

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                chip(nil, "All")
                // Only offer a filter that would return something.
                ForEach(VisitStatus.allCases.filter(has), id: \.self) { chip($0, $0.title) }
            }
            .padding(.horizontal, Metrics.margin)
            // The fill and label swap together as selection moves between chips.
            .animatedChange(selection, reduceMotion: reduceMotion)
        }
        .scrollIndicators(.hidden)
    }

    private func chip(_ status: VisitStatus?, _ title: String) -> some View {
        let selected = selection == status
        let tint = status?.tint ?? .accentColor
        // Tapping the active chip clears it — a filter you can't undo is a trap.
        return Button { selection = selected ? nil : status } label: {
            Text("\(title)  \(count(status))")
                .font(.subheadline).monospacedDigit()
                .padding(.horizontal, 12).padding(.vertical, 6)
                .foregroundStyle(selected ? .white : tint)
                .background(selected ? tint : tint.opacity(0.12), in: .capsule)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title), \(count(status)) visits")
        .accessibilityAddTraits(selected ? [.isSelected, .isButton] : .isButton)
    }
}
