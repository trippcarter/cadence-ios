import Foundation
import SwiftData

// MARK: - MemberRole

/// Household membership role. Owners can invite/remove members and delete the
/// household; members can create/edit lists and tasks; guests are read-only.
/// Build 15 ships the field + UI gating but does NOT enforce permissions at
/// the CloudKit layer — that's a follow-up once household-level CKShare
/// zone unification lands.
enum MemberRole: String, Codable, CaseIterable {
    case owner
    case member
    case guest

    var displayName: String {
        switch self {
        case .owner:  return "Owner"
        case .member: return "Member"
        case .guest:  return "Guest"
        }
    }
}

// MARK: - Household

/// A grouping of shared lists + members (e.g., "Carter Family",
/// "Honey Brake Team"). One user can belong to multiple households.
///
/// Build 15 ships the *grouping* — lists are visually parented under a
/// household and tasks within can be assigned to members. Cross-device
/// sharing in v1 still flows through the per-list CKShare zones from
/// Phase 4. A future build will collapse those into a single CKShare per
/// household to make invitation one-step.
@Model
final class Household {
    // CloudKit-backed SwiftData requires every attribute to have a default
    // value at declaration. No @Attribute(.unique) — CloudKit doesn't
    // support unique constraints.
    var id: UUID = UUID()
    var name: String = ""
    var iconKey: String = "house.fill"
    var colorKey: String = "violet"
    var createdAt: Date = Date.now
    /// Apple Sign-In identifier of the user who created the household.
    /// Used to seed the first HouseholdMembership with role = .owner.
    var createdBy: String = ""
    /// Reserved for the future household-zone CKShare migration. nil today.
    var ckZoneId: String?

    @Relationship(deleteRule: .cascade, inverse: \TaskList.household)
    var lists: [TaskList]?

    @Relationship(deleteRule: .cascade, inverse: \HouseholdMembership.household)
    var memberships: [HouseholdMembership]?

    /// Non-optional accessors for the UI to read without manual unwrap.
    var listsArray: [TaskList] { lists ?? [] }
    var membershipsArray: [HouseholdMembership] { memberships ?? [] }

    init(
        id: UUID = UUID(),
        name: String,
        iconKey: String = "house.fill",
        colorKey: String = "violet",
        createdAt: Date = .now,
        createdBy: String = ""
    ) {
        self.id = id
        self.name = name
        self.iconKey = iconKey
        self.colorKey = colorKey
        self.createdAt = createdAt
        self.createdBy = createdBy
    }
}

// MARK: - HouseholdMembership

/// A single user's membership in a Household. Captures the user's display
/// name + email + assigned avatar color so the UI can render assignee chips
/// without a network round-trip to CloudKit identity services.
@Model
final class HouseholdMembership {
    var id: UUID = UUID()
    var household: Household?
    /// Apple Sign-In identifier of the member. Stable per app-per-Apple-ID.
    var userIdentifier: String = ""
    /// Cached at invite-accept time so we can show the right name in the
    /// member picker + assignee chip without a CloudKit roundtrip every
    /// time the row renders.
    var displayName: String = ""
    var email: String?
    /// One of `ListPalette.allKeys`. Assigned at join time and stays stable
    /// so each member has a consistent color across the app.
    var avatarColorKey: String = "violet"
    /// Stored as the rawValue String so SwiftData's CloudKit migration
    /// stays compatible; resolved through the computed `role` accessor.
    var roleRaw: String = MemberRole.member.rawValue
    var joinedAt: Date = Date.now

    var role: MemberRole {
        get { MemberRole(rawValue: roleRaw) ?? .member }
        set { roleRaw = newValue.rawValue }
    }

    /// First letter of displayName for the avatar bubble. "?" when name is
    /// unknown (extremely rare — invite-accept always captures a name).
    var avatarInitial: String {
        guard let first = displayName.first else { return "?" }
        return String(first).uppercased()
    }

    init(
        id: UUID = UUID(),
        household: Household? = nil,
        userIdentifier: String,
        displayName: String,
        email: String? = nil,
        avatarColorKey: String = "violet",
        role: MemberRole = .member,
        joinedAt: Date = .now
    ) {
        self.id = id
        self.household = household
        self.userIdentifier = userIdentifier
        self.displayName = displayName
        self.email = email
        self.avatarColorKey = avatarColorKey
        self.roleRaw = role.rawValue
        self.joinedAt = joinedAt
    }
}
