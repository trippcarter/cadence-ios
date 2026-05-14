# Cadence

Cadence is a polished, calm task and calendar companion for iPhone and Mac — built to run the day across personal life and shared business without feeling like enterprise software. It focuses on five things: a single Today view that mixes tasks and calendar events, automatic rollover so incomplete work never falls off the radar, shared lists for collaborating with a co-owner, deep iOS integration (widgets, Lock Screen, Siri, notifications), and an AI layer powered by Claude that helps plan the day and capture work in natural language.

The app is iPhone-first and Mac-second, built on a single SwiftUI codebase with SwiftData and CloudKit for storage and sync. No third-party backend; everything runs through Apple's free tier. See [`docs/Cadence_Product_Spec.pdf`](docs/Cadence_Product_Spec.pdf) for the full vision and feature scope, and [`docs/Cadence_Architecture.pdf`](docs/Cadence_Architecture.pdf) for the stack, data model, and 11-phase build plan.

## Getting started

Cadence's Xcode project is generated from [`project.yml`](project.yml) using [XcodeGen](https://github.com/yonaskolb/XcodeGen). The generated `Cadence.xcodeproj` is not committed.

```bash
# one-time install
brew install xcodegen

# regenerate the Xcode project after pulling or changing project.yml
xcodegen generate

# then open it
open Cadence.xcodeproj
```

## Status

Phase 0 — project scaffolding only. Feature development begins in Phase 1.
