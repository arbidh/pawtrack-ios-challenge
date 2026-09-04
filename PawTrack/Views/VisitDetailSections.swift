import SwiftUI

/// The detail screen's sections, one small view each so the screen itself reads as a
/// list of what it shows.
enum VisitSections {}

// MARK: - Latest photo

extension VisitSections {

    /// The captures the sitter has taken, centred at the top and swipeable when there's
    /// more than one.
    ///
    /// Only photos held on this device. The feed lists filenames (`photo_001.jpg`) whose
    /// bytes were never shipped; those appear in the strip below, where "On server" is a
    /// proportionate thing to say rather than a full-width placeholder.
    struct LatestPhoto: View {
        let visit: Visit
        let store: PhotoStore
        let onDelete: (String) -> Void

        @Environment(\.accessibilityReduceMotion) private var reduceMotion
        @State private var current: String?

        static func local(in visit: Visit) -> [Visit.Photo] {
            visit.photos.filter(\.isLocal).sorted { $0.at > $1.at }
        }

        private var photos: [Visit.Photo] { Self.local(in: visit) }

        private var shown: Visit.Photo? {
            photos.first { $0.id == current } ?? photos.first
        }

        var body: some View {
            if !photos.isEmpty {
                Section {
                    VStack(spacing: 10) {
                        TabView(selection: $current) {
                            ForEach(photos) { photo in
                                // The frame belongs to the page, not the pager: as an
                                // overlay on the taller paging container it sat above
                                // the image and let it bleed past the corners.
                                PhotoView(photo: photo, store: store, side: Metrics.heroPhoto, corner: 20)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 20)
                                            .strokeBorder(Color(.systemBackground), lineWidth: 5)
                                    )
                                    .shadow(color: .black.opacity(0.16), radius: 12, y: 5)
                                    .contextMenu {
                                        Button("Delete Photo", systemImage: "trash", role: .destructive) {
                                            onDelete(photo.id)
                                        }
                                    }
                                    .tag(Optional(photo.id))
                            }
                        }
                        // Page dots only earn their place past one photo.
                        .tabViewStyle(.page(indexDisplayMode: photos.count > 1 ? .always : .never))
                        .frame(width: Metrics.heroPhoto, height: Metrics.heroPhoto + 30)

                        if let shown {
                            Text(caption(for: shown))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .contentTransition(.opacity)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .transition(.scale(scale: 0.92).combined(with: .opacity))
                .animatedChange(photos.map(\.id), reduceMotion: reduceMotion)
                // Keep the visible page valid when a photo is added or deleted.
                .onChange(of: photos.map(\.id)) { _, ids in
                    if current == nil || !ids.contains(current!) { current = ids.first }
                }
            }
        }

        private func caption(for photo: Visit.Photo) -> String {
            let time = photo.at.formatted(date: .omitted, time: .shortened)
            guard photos.count > 1, let index = photos.firstIndex(where: { $0.id == photo.id }) else {
                return "Latest proof · \(time)"
            }
            return "Proof \(index + 1) of \(photos.count) · \(time)"
        }
    }
}

// MARK: - Summary

extension VisitSections {

    struct Summary: View {
        let visit: Visit

        private var mapsURL: URL? {
            visit.address?.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
                .flatMap { URL(string: "maps://?q=\($0)") }
        }

        var body: some View {
            Section {
                LabeledContent("Owner", value: visit.ownerName)
                LabeledContent("Pet", value: visit.petType.capitalized)
                LabeledContent("Address") {
                    Text(visit.address ?? "Not provided")
                        .foregroundStyle(visit.address == nil ? .tertiary : .secondary)
                }
                LabeledContent("Scheduled", value: visit.scheduleText)
                // Hidden for v_005, which has no address to navigate to.
                if let mapsURL {
                    Link("Get Directions", destination: mapsURL)
                }
            } header: {
                HStack {
                    Text("Visit")
                    Spacer()
                    StatusBadge(status: visit.status)
                }
            }
        }
    }
}

// MARK: - Progress

extension VisitSections {

    /// The steps this device recorded, and the one transition that's legal next. A visit
    /// that arrived mid-flight has no local history, and inventing times would falsify a
    /// service record.
    struct Progress: View {
        let visit: Visit
        let onAdvance: () async -> Void

        @Environment(\.accessibilityReduceMotion) private var reduceMotion

        var body: some View {
            Section("Progress") {
                if visit.history.isEmpty, visit.status.next != nil {
                    Text("No steps recorded yet.").font(.subheadline).foregroundStyle(.secondary)
                }

                ForEach(visit.history, id: \.at) { change in
                    // Each recorded step drops in as it happens.
                    LabeledContent {
                        Text(change.at.formatted(date: .omitted, time: .shortened)).monospacedDigit()
                    } label: {
                        Label(change.status.title, systemImage: "checkmark.circle.fill")
                            .foregroundStyle(change.status.tint)
                    }
                }

                if let next = visit.status.next {
                    advanceButton(to: next)
                        .transition(.opacity)
                } else {
                    Label(visit.status.terminalMessage, systemImage: visit.status.symbol)
                        .font(.subheadline).foregroundStyle(visit.status.tint)
                }
            }
            // Checking in changes three things at once — the trail, the button and the
            // badge — so they move together.
            .animatedChange(visit.status, reduceMotion: reduceMotion)
            // A check-in is a physical act, usually one-handed with a lead in the other,
            // and often without looking. Finishing the visit gets the success tap; the
            // steps on the way get a lighter one.
            .sensoryFeedback(trigger: visit.status) { old, new in
                guard old != new else { return nil }
                // `cancelled` and `unknown` arrive from the office on a refresh, not from
                // this button — a congratulatory tap for either would be a lie.
                let feedback: SensoryFeedback? = switch new {
                case .completed: .success
                case .enRoute, .inProgress: .impact(weight: .medium)
                case .upcoming, .cancelled, .unknown: nil
                }
                return feedback
            }
        }

        private func advanceButton(to next: VisitStatus) -> some View {
            Button { Task { await onAdvance() } } label: {
                Label(next.actionTitle, systemImage: next.symbol)
                    .fontWeight(.semibold).foregroundStyle(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .tint(next.tint)
            .accessibilityHint("Marks this visit as \(next.title.lowercased())")
        }
    }
}

// MARK: - Photos

extension VisitSections {

    struct Photos: View {
        let visit: Visit
        let model: VisitDetailViewModel
        let chooseFromLibrary: () -> Void
        let onDelete: (String) -> Void

        var body: some View {
            Section {
                // The feed records photos taken on an earlier visit but ships no bytes
                // for them. Grey tiles read as broken thumbnails, so say it instead —
                // the sitter needs to know the record isn't empty without being shown
                // two placeholders that look like a failure.
                if !onServer.isEmpty {
                    Label(
                        "\(onServer.count) earlier photo\(onServer.count == 1 ? "" : "s") on file, not downloaded to this device.",
                        systemImage: "icloud.slash"
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
                addButtons
                if model.isSaving {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("Saving photo…").font(.subheadline).foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Photos")
            } footer: {
                if !model.hasCamera {
                    Text("No camera on this device — choose from the library instead.")
                } else if model.needsPhotoProof {
                    Text("This owner asked for photo proof of the visit.").foregroundStyle(.orange)
                }
            }
        }

        /// Photos the feed knows about but never shipped bytes for.
        private var onServer: [Visit.Photo] {
            visit.photos.filter { !$0.isLocal }
        }

        private var addButtons: some View {
            HStack(spacing: 12) {
                // Hidden, not disabled, without a camera: a dead button reads as broken.
                if model.hasCamera {
                    Button { Task { await model.startCamera() } } label: {
                        Label("Take Photo", systemImage: "camera.fill").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
                Button(action: chooseFromLibrary) {
                    Label("Library", systemImage: "photo.on.rectangle").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
    }
}

// MARK: - Care and instructions

extension VisitSections {

    /// Absent for the rabbit at `v_004`, which has no directory entry.
    struct Care: View {
        let pet: Pet?

        var body: some View {
            if let pet {
                Section("Care") {
                    LabeledContent("Breed", value: "\(pet.breed), \(pet.age)y, \(pet.weight) lb")
                    LabeledContent("Temperament") {
                        Text(pet.temperament.capitalized)
                            .foregroundStyle(pet.needsCare ? .orange : .secondary)
                    }
                    Text(pet.feedingInstructions).font(.subheadline)
                    Text(pet.vetContact).font(.subheadline).foregroundStyle(.secondary)
                }
            }
        }
    }

    struct Instructions: View {
        let visit: Visit

        var body: some View {
            if visit.specialInstructions != nil || visit.notes != nil {
                Section("Instructions") {
                    if let special = visit.specialInstructions {
                        Label(special, systemImage: "exclamationmark.triangle.fill")
                            .font(.subheadline).foregroundStyle(.orange)
                    }
                    if let notes = visit.notes {
                        Text(notes).font(.subheadline).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}
