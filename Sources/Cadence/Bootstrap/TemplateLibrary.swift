import Foundation

/// Curated list templates organized by life context. Each template seeds a
/// new TaskList plus 3–5 starter TaskItems the user can edit or delete.
///
/// Used by `TemplateGallerySheet` (the post-sign-in Quick Start chooser, and
/// the "From template" entry point in the Lists tab).
enum TemplateLibrary {

    struct Template: Identifiable, Hashable {
        let id: String
        let name: String
        let colorKey: String
        let iconKey: String
        /// Starter task titles. Inserted into the new list at top-level
        /// (no due date — the user can schedule them as they want).
        let starterTasks: [String]
    }

    enum Category: String, CaseIterable, Identifiable {
        case personal = "Personal"
        case family = "Family"
        case business = "Business"
        case outdoor = "Outdoor & Hobby"
        case projects = "Projects"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .personal: return "person.fill"
            case .family:   return "house.fill"
            case .business: return "briefcase.fill"
            case .outdoor:  return "leaf.fill"
            case .projects: return "hammer.fill"
            }
        }

        var accentKey: String {
            switch self {
            case .personal: return "violet"
            case .family:   return "pink"
            case .business: return "amber"
            case .outdoor:  return "teal"
            case .projects: return "indigo"
            }
        }
    }

    static func templates(in category: Category) -> [Template] {
        switch category {
        case .personal:    return personalTemplates
        case .family:      return familyTemplates
        case .business:    return businessTemplates
        case .outdoor:     return outdoorTemplates
        case .projects:    return projectsTemplates
        }
    }

    // MARK: Personal

    private static let personalTemplates: [Template] = [
        Template(id: "personal-daily-routine", name: "Daily routine", colorKey: "violet", iconKey: "sun.max.fill",
                 starterTasks: ["Morning stretch", "Make the bed", "Hydrate (32 oz before 10am)", "Evening review", "Lights out by 11"]),
        Template(id: "personal-self-care", name: "Self-care", colorKey: "pink", iconKey: "heart.fill",
                 starterTasks: ["20 min of sunlight", "Read 10 pages", "Journal 1 thing I noticed today", "Call someone I love", "10 min of stillness"]),
        Template(id: "personal-reading", name: "Reading list", colorKey: "indigo", iconKey: "book.fill",
                 starterTasks: ["Currently reading…", "Up next: pick a book", "Library hold to set up", "Annotate 1 quote per book"]),
        Template(id: "personal-health", name: "Health goals", colorKey: "mint", iconKey: "figure.run",
                 starterTasks: ["3 workouts this week", "Drink 80 oz water daily", "Schedule annual physical", "Try one new healthy recipe", "Track sleep this week"]),
        Template(id: "personal-weekend", name: "Weekend chores", colorKey: "amber", iconKey: "house.fill",
                 starterTasks: ["Laundry", "Groceries for the week", "Take out trash + recycling", "Quick kitchen reset", "Plan next week's meals"]),
    ]

    // MARK: Family

    private static let familyTemplates: [Template] = [
        Template(id: "family-meal-plan", name: "Weekly meal plan", colorKey: "amber", iconKey: "fork.knife",
                 starterTasks: ["Monday dinner: ___", "Tuesday dinner: ___", "Wednesday dinner: ___", "Thursday dinner: ___", "Friday: takeout night"]),
        Template(id: "family-kids", name: "Kids' activities", colorKey: "pink", iconKey: "figure.2.and.child.holdinghands",
                 starterTasks: ["Sign up for next-season sport", "Library trip this week", "School calendar to check", "Friend playdate to coordinate"]),
        Template(id: "family-events", name: "Family events", colorKey: "violet", iconKey: "calendar.badge.plus",
                 starterTasks: ["Upcoming birthdays this month", "Send anniversary card", "Plan next family dinner", "Book reservation"]),
        Template(id: "family-home", name: "Home maintenance", colorKey: "teal", iconKey: "wrench.and.screwdriver.fill",
                 starterTasks: ["Change air filter", "Test smoke alarm batteries", "Lawn / yard quick-check", "Check water heater", "Pest control quarterly"]),
        Template(id: "family-vacation", name: "Vacation planning", colorKey: "orange", iconKey: "airplane",
                 starterTasks: ["Pick destination + dates", "Book flights / drive plan", "Lodging reservation", "Packing list start", "Pet sitter / mail hold"]),
    ]

    // MARK: Business

    private static let businessTemplates: [Template] = [
        Template(id: "biz-standup", name: "Daily standup prep", colorKey: "violet", iconKey: "person.2.fill",
                 starterTasks: ["Yesterday's wins", "Today's focus (top 1)", "Blockers / asks", "1 thing I'm thinking about"]),
        Template(id: "biz-followups", name: "Client follow-ups", colorKey: "amber", iconKey: "envelope.fill",
                 starterTasks: ["Reply to overdue threads", "Weekly check-in emails", "Proposal follow-ups", "Thank-you notes after meetings"]),
        Template(id: "biz-quarter", name: "Quarterly planning", colorKey: "indigo", iconKey: "chart.bar.fill",
                 starterTasks: ["Top 3 quarter goals", "Numbers I want to hit", "Risks + mitigations", "Review last quarter", "Schedule monthly check-ins"]),
        Template(id: "biz-hiring", name: "Hiring pipeline", colorKey: "teal", iconKey: "person.crop.rectangle.stack.fill",
                 starterTasks: ["Open roles: ___", "Interviews to schedule", "Reference checks pending", "Offers out", "Onboarding for new hires"]),
        Template(id: "biz-vendors", name: "Vendor list", colorKey: "neutral", iconKey: "tray.full.fill",
                 starterTasks: ["Active vendors + key contacts", "Renewals this quarter", "Net-30 invoices to send", "Comparison: looking for ___"]),
    ]

    // MARK: Outdoor & Hobby

    private static let outdoorTemplates: [Template] = [
        Template(id: "outdoor-hunting", name: "Hunting trip prep", colorKey: "amber", iconKey: "scope",
                 starterTasks: ["License + tags", "Sight-in rifle / bow", "Pack: clothes, optics, knives", "Food + water for blind", "Route + check-in plan"]),
        Template(id: "outdoor-boat", name: "Boat day prep", colorKey: "teal", iconKey: "sailboat.fill",
                 starterTasks: ["Fuel + oil check", "Cooler + ice", "Life vests on board", "Tow strap + first aid", "File float plan with someone"]),
        Template(id: "outdoor-fishing", name: "Fishing gear", colorKey: "indigo", iconKey: "fish.fill",
                 starterTasks: ["Tackle: re-tie leaders", "Bait pickup", "License current?", "Pack pliers + line cutter", "Check forecast + tides"]),
        Template(id: "outdoor-camping", name: "Camping checklist", colorKey: "mint", iconKey: "tent.fill",
                 starterTasks: ["Tent + stakes + footprint", "Sleep system (bag + pad)", "Stove + fuel + cookware", "Headlamp + extra batteries", "Permits / reservation"]),
        Template(id: "outdoor-packing", name: "Travel packing", colorKey: "orange", iconKey: "suitcase.fill",
                 starterTasks: ["Documents (ID, tickets, cash)", "Toiletries", "Chargers + adapters", "Clothing by day", "Meds + first aid"]),
    ]

    // MARK: Projects

    private static let projectsTemplates: [Template] = [
        Template(id: "proj-reno", name: "House renovation", colorKey: "amber", iconKey: "hammer.fill",
                 starterTasks: ["Scope + budget draft", "Contractor bids (3+)", "Permit research", "Demolition plan", "Punch-list at end"]),
        Template(id: "proj-launch", name: "Side project launch", colorKey: "violet", iconKey: "lightbulb.fill",
                 starterTasks: ["Landing page copy", "MVP feature list", "Pricing decision", "First 10 users to invite", "Launch tweet thread"]),
        Template(id: "proj-course", name: "Course / learning", colorKey: "indigo", iconKey: "graduationcap.fill",
                 starterTasks: ["Pick the course", "Schedule study blocks", "Module 1 to finish", "Notes + flashcards", "Final exam / capstone"]),
        Template(id: "proj-event", name: "Event planning", colorKey: "pink", iconKey: "calendar.badge.plus",
                 starterTasks: ["Date + venue locked", "Invite list + send", "Catering / food plan", "Day-of run-of-show", "Thank-you notes after"]),
        Template(id: "proj-wedding", name: "Wedding prep", colorKey: "rose", iconKey: "heart.circle.fill",
                 starterTasks: ["Venue contract signed", "Guest list final", "Vendors: photo, food, music", "Attire + fittings", "Marriage license"]),
    ]
}
