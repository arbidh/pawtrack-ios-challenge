# PawTrack — Design Decisions

## Scope

All three required features, plus both bonus features. Photos can be deleted as well as
captured — a sitter who takes a bad shot shouldn't be stuck with it on a record the
client sees.

The starter code had three bugs and I fixed all of them. The first one mattered
most: `Visit` declared every field non-optional, so `JSONDecoder` threw on the very
first record in the provided data and the list could never show anything at all.

Not done, and why:

- **A sync queue.** Changes are saved locally, but nothing pushes them to a server.
  That's the real offline story and it needs retry, collapsing of repeated status
  changes, and idempotency keys so a retry can't double-record a check-in. The design
  I'd write is at the bottom of this file.
- **Photo upload.** Same reason — captures live on the device only.
- A full-screen photo viewer, iPad layout, localisation.

Motion is used where it explains a state change and nowhere else: rows slide out when a
filter removes them, the status pill re-colours in place, a new capture scales into the
hero slot, and checking in moves the trail, the button and the badge together. All of it
goes through one `animatedChange` helper that returns no animation when Reduce Motion is
on — one place to tune the feel, one place that respects the setting.

The row layout adapts at accessibility text sizes: the timetable column would take
most of the width and squeeze the pet name out, so the row stacks instead. Verified
at AX5 on the narrowest device the iOS 26 simulator offers.

## Architecture
> What pattern did you use and why? What trade-offs did you consider?

MVVM, with `VisitListViewModel` owning the schedule and `VisitDetailViewModel` reading
and mutating through it.

Both screens work on the same visits, so they share one view model instance rather than
holding separate copies. With a copy each, checking in on the detail screen leaves the
list showing the old status until something forces a reload.

I did consider a `VisitRepository` between the view models and the services. I left it
out. With two screens it would be a class that forwards calls and holds no logic of its
own, and the cost of adding it later is small. The dependency it saves me from is
`VisitDetailViewModel` knowing about `VisitListViewModel`, which I'm not thrilled about
but can live with at this size. That's the first thing I'd extract if a third screen
appeared.

The target builds with `SWIFT_STRICT_CONCURRENCY = complete` — and cleanly in Swift 6
language mode — so isolation is checked by the compiler rather than by review. Three
boundaries carry the app's concurrency: `VisitListViewModel` is `@MainActor`,
`VisitCache` is an `actor` so overlapping saves can't land out of order, and
`PhotoStore` is `@unchecked Sendable` because `NSCache` is thread-safe but unmarked.

`VisitListViewModel` is `@MainActor` rather than an actor. Everything on it is UI state,
and the dataset is one sitter's day. The genuinely expensive work — JPEG encoding, image
decoding, file I/O — is pushed off the main actor inside `PhotoStore` and `VisitCache`.
An actor here would add a hop to every property read for isolation I don't need.

The seam that matters is `NetworkClient`. Swapping the bundled JSON for a real API is a
one-line change in `PawTrackApp`, and the tests inject a stub through the same protocol.

## Data Modeling
> How did you handle the provided data? Any issues you encountered?

The wire format is a private type inside `NetworkClient`, separate from `Visit`. That
keeps the feed's shape out of the views, and it keeps `Visit`'s own `Codable` symmetric
so the same type round-trips through the on-disk cache.

`petName` and `address` are optional on `Visit`. They arrive null or blank, and defaulting
them to `""` at the boundary just moves the problem — an empty string renders as a
believable blank row, whereas an optional forces the UI to decide what to say.

`petType` stays a `String`. An enum would have to either drop the rabbit in `v_004` or
carry an `unknown` case, and neither buys anything here.

## Data Quality
> Did you encounter any issues with the provided data? How did you handle them?

Seven problems. I repaired all of them rather than dropping records, and logged each
repair so a bad feed looks like a bad feed rather than a bug in the app.

 Record  Problem | What I did 
 `v_003`  Appears twice  Keep the first. There's no `updatedAt` to pick a winner with, and "first" at least stays stable between refreshes. 
 `v_004`  `petName` is null  Falls back to "Tom Whitfield's rabbit", shown in secondary text so it doesn't read as the real name. 
 `v_004`  `petType` is "rabbit"  No pet profile exists, so the Care section doesn't render. Nothing else cares. 
 `v_005`  `address` is `""`  Becomes nil. The row says "No address on file" and Get Directions is hidden. 
 `v_006`  Window ends 90 min before it starts | Keep the start, drop the end, show "From 5:00 PM". Picking which end was the typo would put an invented time on a service record. 
 `v_007` No window at all | Sorts last, shows "no time". 
 `v_009`  Status is "cancelled"  A real terminal state, not a step on the path. No transition is offered. 

Decoding is per-element through a wrapper that can't throw, so one malformed record
doesn't cost the sitter the other eight. Catching around a plain `decode` doesn't work
here: an unkeyed container doesn't advance past an element that threw, so the loop spins.

## State Management
> How do you manage visit state transitions? Where does business logic live?

On the model. `VisitStatus.next` gives each status exactly one successor, so skipping a
step isn't something to validate against — it can't be expressed. `Visit.advance(to:at:)`
throws if you try, and it's the only way to change status; `status` and `history` are
`private(set)`.

Putting the rule in the view model or in a button's `isEnabled` would leave it reachable
from a stale view. The UI offers exactly one button because exactly one move is legal.

Each transition appends to `history` with its timestamp. The detail screen shows that
history and nothing else — a visit that arrives from the feed already in progress has no
local record, so it shows none. Inventing a time on a document meant to settle disputes
with clients seemed worse than showing nothing.

On refresh the office wins on descriptive fields, the sitter wins on progress. A refresh
must never walk a checked-in visit back to `upcoming`. The one exception is a
cancellation, which is server-owned: it arrives with no history, so without a special
case the sitter would keep driving to a visit the office called off.

## Photo Storage
> How and where are captured photos stored? Why?

JPEGs on disk in Application Support, referenced from the model by filename. The visits
themselves are a `Codable` snapshot in the same directory.

Not SwiftData or Core Data. This is one sitter's day, read whole and written whole, with
no relational queries and nothing to gain from faulting. A snapshot is a struct and two
functions, and the migration story is "throw it away and refetch".

Captures are scaled to a 1600px long edge before saving. A raw capture is several
megabytes and proof of service doesn't need that, and on this app's premise every byte
eventually crosses a client's bad Wi-Fi.

Thumbnails come back through ImageIO at the size they're displayed. I tried
`UIImage.byPreparingThumbnail(ofSize:)` first and it returns nil when the requested
aspect ratio doesn't match the source, which left every tile spinning.
`kCGImageSourceThumbnailMaxPixelSize` bounds the long edge and keeps the ratio.

Both writes use `.atomic` and complete file protection. Photos of a client's front door
are at least as sensitive as their address.

## Starter Code
> Did you modify any of the provided code? What and why?

All five provided Swift files. Four were modified in place; one was deleted and
replaced, which I want to be explicit about.

**`Visit`** — every field was non-optional, so `JSONDecoder` threw on the very first
record in the provided data and the list could never show anything at all. Fields the
feed sends null or blank are optional now.

**`VisitListViewModel`** — three separate problems. The `delegate` was held strongly on
a protocol that wasn't `AnyObject`, so the view model and its host kept each other
alive. The `Timer` captured `self` and was never invalidated, so it outlived its screen
and kept fetching; on the default run loop mode it also stopped firing while the list
was scrolling. And `visits`/`isLoading` were mutated inside a detached `Task` with no
isolation — a data race that also delivered UI updates off the main thread.

I dropped the 30-second polling rather than fixing it. It wakes the radio on a schedule
unrelated to whether anything changed, and a sitter's own assignments rarely change
mid-shift. Refresh happens on appear and on pull; push is the right answer if the office
needs to reassign live.

**`NetworkClient`** — kept the protocol seam, rewrote the mock. It decoded straight into
`Visit`, so the wire format's problems reached every view, and one malformed record threw
away the whole day.

**`PawTrackApp`** — wires up the view model.

**`ImageLoader` — deleted, replaced by `PhotoStore`.** This is the one file I removed
rather than fixed, so the reasoning matters:

- Its four defects were structural, not incidental: a plain `Dictionary` mutated from any
  thread (a data race, and the reason a shared cache like that crashes under scrolling),
  a synchronous `Data(contentsOf:)` on the caller's thread, no eviction of any kind, and
  full-size decoding for images displayed in a 78pt tile.
- More importantly, its *responsibility* was wrong for the feature. It only read images
  from URLs. Photo capture needs to write bytes to disk, and a type that both saves and
  loads is no longer an "image loader" — keeping the name would have been the misleading
  choice.

Nothing was lost: `PhotoStore` still caches (via `NSCache`, which evicts under memory
pressure instead of growing forever) and still loads on demand, now off the main thread
and downsampled to the size actually displayed.

## Testing

Ten tests, aimed at what would quietly lose a sitter's work rather than at coverage.

Transitions: skipping, going backwards and both terminal states are rejected; each step
records its own timestamp; a refresh can't undo local progress, and a cancellation still
wins. A status this build has never heard of decodes to `unknown`, which has no successor,
so it can't be handed a *Start driving* button.

Decoding: the repairs above, run against the real bundled `visits.json`. All of these fail
against the original `Visit`, so they pin the bug that made the app show nothing.

Offline: a check-in survives a relaunch with the network down, and filter and search
compose while the chip counts stay taken from the unfiltered set.

Camera permission isn't covered. I had an injected seam for it and took it out — one
protocol and two closures existing only for four tests wasn't worth the indirection here.
I'd put it back the moment that logic grows.

## What I'd Do With More Time
> If this were a real project, what would you add or change next?

1. **A sync queue.** Changes are saved locally but nothing sends them to a server. I'd
   persist pending mutations, drain them on foreground and on connectivity, with retry,
   collapsing of repeated status changes, and idempotency keys so a retry can't
   double-record a check-in. That also wants `updatedAt` per field from the backend,
   which would replace the merge heuristic above.
2. **Photo upload in the background**, via `URLSession` background transfers, so a
   capture finishes uploading after the app is suspended.
3. **Extract a repository** once a third screen needs the visits.
4. **Location-verified check-in.** It's the obvious next thing for proof of service, and
   it turns `v_005`'s missing address into an operational problem rather than a cosmetic
   one.
5. **Snapshot tests at large text sizes.** Two bugs here only turned up by running the
   app: a long fallback name hyphenating the status badge, and the empty state flashing
   on cold launch before the first fetch started.
6. **Animation and Professional UI Design.** Animation when needed and some UI Changes.

## Dependencies

None beyond XcodeGen, which the project already required.
