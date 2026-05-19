# Crash fixes log

Postmortem of crashes that hit real-device users + the prevention
checklist baked from each one.

---

## Build 18 → Build 19 — SwiftData container init crash on launch

### Crash signature

App fails to launch on Tripp's iPhone immediately after upgrading to
Build 18. SwiftData's `ModelContainer` constructor throws an error,
the App init's `fatalError("Could not create ModelContainer: ...")`
fires, and the process is terminated by iOS before any UI renders.

Console.app filtered for `Cadence-Boot` (added in Build 19) now shows
the underlying SwiftData error in plain text — previously the crash
was opaque because the fatalError swallowed it.

### Root cause

Build 18 added two new `@Model` types — `FocusSession` and
`HabitCompletion` — each with a `var task: TaskItem?` relationship.
Neither relationship had a matching **inverse** declared on `TaskItem`.

CloudKit-backed SwiftData has a hard requirement that every
relationship must have an inverse on the other side. Without it,
`ModelContainer(for:configurations:)` throws at initialization.

The crash was deterministic on devices that already had a Build 17
schema on disk (i.e. every existing user). Fresh-install simulators
sometimes papered over the issue.

### Fix (commit Build 19)

1. **Added the missing inverses** on `TaskItem`:

   ```swift
   @Relationship(deleteRule: .cascade, inverse: \FocusSession.task)
   var focusSessions: [FocusSession]?

   @Relationship(deleteRule: .cascade, inverse: \HabitCompletion.task)
   var habitCompletions: [HabitCompletion]?
   ```

2. **Replaced `fatalError`** in `CadenceApp.init` with a safe
   try/catch that captures the error and renders a recoverable
   `ContainerRecoveryView`. The view offers:
   - **Retry** — re-runs container init (sometimes works after a
     transient CloudKit hiccup)
   - **Reset local cache** — confirmed-destructive — wipes the
     on-disk `.sqlite` / `-wal` / `-shm` files and retries. CloudKit-
     backed data re-downloads automatically on next sync tick.
   - **Error details** disclosure with the verbatim Swift error.

3. **Added `[Cadence-Boot]` NSLog** at the failure point so
   Console.app on the Mac can show the underlying error verbatim.

### Pre-build checklist for future schema changes

Run through this list every time you add or modify a `@Model` type
before shipping:

- [ ] **Every relationship has an inverse on the other side.**
  - If model A has `var foo: B?`, model B must have a corresponding
    `@Relationship(deleteRule: .cascade, inverse: \A.foo) var bars: [A]?`
  - Missing inverses are the #1 cause of CloudKit-backed container
    init failures.
- [ ] **Every new stored property has a default value at declaration
  OR is Optional.**
  - `var foo: Bool = false` — good
  - `var foo: String?` — good
  - `var foo: Int` — BAD, will crash on migration from prior schema
- [ ] **No `@Attribute(.unique)`** on any new field. CloudKit doesn't
  support unique constraints and SwiftData throws.
- [ ] **New model types registered in BOTH schemas** in
  `SharedContainer.makeContainer()`:
  - The `unifiedSchema` array
  - The `cloudSchema` inside `makeCloudConfig()`
- [ ] **If the widget extension target compiles** any file that
  imports the new model, add the model file to the widget's
  `sources:` in `project.yml`.
- [ ] **Smoke test on simulator first, then real device.** Real
  devices hit the migration path because they have existing data;
  simulators with cleared state don't.
- [ ] **Diff the SwiftData schema before merging.** If the change is
  big (new entity, new relationship), consider declaring a
  `VersionedSchema` + `SchemaMigrationPlan` even though lightweight
  migration would normally work — the explicit plan documents intent
  and gives you a hook for future ratcheting.

### Why we didn't catch this pre-ship

- The Build 18 simulator build had a clean (Build 17-empty) store,
  so the migration path didn't run there.
- The container init test was a "does it compile and produce a
  binary" check, not "does the binary launch with prior-build data
  on disk."
- The model files were authored in isolation, so the inverse-rel
  contract wasn't visible at the point of adding the new types.

The pre-build checklist above is the durable answer; the
`ContainerRecoveryView` is the seatbelt.

---
