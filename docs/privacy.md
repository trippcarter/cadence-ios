---
layout: default
title: Privacy Policy
permalink: /privacy
---

# Cadence Privacy Policy

**Last updated:** May 19, 2026

Cadence is a personal task and calendar app made by a solo developer (Tripp Carter). This policy explains what data Cadence collects, where it lives, and what you can do about it. We've kept the language plain because that's how privacy policies should read.

## The short version

- Cadence stores your tasks, lists, and habits in **your personal iCloud account**. We never see them.
- Sign-in is **Sign in with Apple**. We get whatever Apple shares (your Apple ID, optionally your name and email).
- If you connect Google Calendar, the connection lives on your device. We don't proxy it through a server.
- We don't sell data. We don't have advertisers. We don't have analytics tracking who you are.
- You can export your data or delete your account from Settings any time.

## What Cadence collects

| Data | Where it's stored | Why |
|---|---|---|
| Apple ID identifier | Device Keychain | To recognize you on relaunch |
| Your name (optional) | Device Keychain + iCloud | To greet you in the app |
| Your email (optional, can be private relay) | Device Keychain | For account recovery and support contact |
| Tasks, lists, spaces (shared groups), habits | Your iCloud private database | The app's content |
| Focus session history | Your iCloud private database | Stats and history |
| Daily review logs and intentions | Your iCloud private database | The review feature |
| Google Calendar access tokens | Device Keychain only | To fetch your events |
| Cached calendar events | Device only (SwiftData) | Offline display |
| App preferences (theme, brief time, etc.) | Device + iCloud via UserDefaults | Settings sync across devices |
| Crash diagnostics | App Group container on your device | Debugging via Settings → About |

## What Cadence does NOT collect

- We do not run analytics. There is no Firebase, no Mixpanel, no PostHog, no third-party tracker.
- We do not have a server collecting your tasks. Cadence syncs directly to your iCloud account using Apple's CloudKit. We have no read access to that database.
- We do not collect device identifiers (IDFA, IDFV) for advertising.
- We do not track your location.
- We do not access your contacts, photos, microphone, or camera unless you explicitly attach one in a task note (and that attachment goes into your iCloud, not ours).

## Third-party services

Cadence integrates with two third parties at your option:

### Google Calendar (optional)
If you connect Google Calendar in Settings → Connected Accounts, Cadence reads your calendar events to display them alongside your tasks. The OAuth token lives in your device's Keychain. Cadence never sends your task data to Google. You can disconnect at any time in Settings, which immediately revokes the token and deletes cached events.

Google's privacy policy applies to the data Google holds about you: [policies.google.com/privacy](https://policies.google.com/privacy)

### Apple iCloud (required for sync)
Cadence uses CloudKit (Apple's cloud database) to sync your data across your iPhone, iPad, and Mac. This sync is encrypted in transit and at rest, and lives in your private iCloud account. We have no visibility into it.

Apple's iCloud privacy details: [apple.com/legal/privacy](https://www.apple.com/legal/privacy/)

## Sharing spaces with other people

When you share a "Space" (a group of lists) with another person, that share creates a CloudKit shared zone in your iCloud account. The recipient sees only the lists and tasks inside that space — nothing else. You can stop sharing at any time, which immediately revokes their access.

## Your rights

You can do any of the following from inside the app, with no contact required:

- **Export your data.** Settings → Account → Export my data. Generates a JSON file containing every task, list, space, habit, and review log. You can save it to Files or email it to yourself.
- **Delete your account.** Settings → Account → Delete my account. Wipes local data and signs you out. Your iCloud-stored data remains tied to your Apple ID — to fully remove it, sign out of iCloud for Cadence in iOS Settings → Apple ID → iCloud → Cadence.
- **Disconnect Google Calendar.** Settings → Connected Accounts → Disconnect. Revokes the token immediately.

## Children

Cadence is not designed for users under 13 and we don't knowingly collect data from anyone under 13.

## Changes to this policy

If we make material changes, we'll surface a notice in the app and update the "Last updated" date at the top.

## Contact

Questions about this policy or your data?

- **Email:** [tripp@mcinnis.net](mailto:tripp@mcinnis.net)
- **GitHub:** [github.com/trippcarter/cadence-ios](https://github.com/trippcarter/cadence-ios)

This is a one-person project, so responses come from a real human.
