# Turbo Tables — Emojitar Identity for Multiplayer Mode (Internal Feature Spec v0.1)

**Prompt for Codex:** You are an expert iOS/SwiftUI engineer. Implement the **Emojitar** identity system and integrate it into **Turbo Tables** multiplayer. Follow this spec precisely. Generate production-grade Swift code with composable SwiftUI views, lightweight state management, and testable architecture. Favor clarity and animation polish over complexity.

---

## 1) Feature Summary

- **Emojitar = Emoji + Color**, selected during onboarding.  
- This becomes each player’s unique in-game identity across all views.  
- Appears beside questions, answers, results, and leaderboards.  
- On correct answers, the player’s Emojitar **glows**, **pulses**, and **celebrates** visually for everyone.  
- Works both offline and synced via Firestore.

---

## 2) Deliverables

- `OnboardingEmojitarView` (emoji + color selector with live preview)  
- `EmojitarBadge` (reusable view for displaying emoji/color)  
- `PlayerProfileStore` abstraction for local + Firestore persistence  
- Integration into multiplayer screens:  
  - `LobbyView`  
  - `CountdownView`  
  - `RoundView`  
  - `ScoreboardView`  
- Lightweight animation + haptics for feedback events  
- Unit + snapshot tests

---

## 3) Data Model

```swift
struct Emojitar: Equatable, Codable {
    var emoji: String
    var colorHex: String
}

struct PlayerProfile: Equatable, Codable, Identifiable {
    var id: String
    var displayName: String
    var emojitar: Emojitar
    var createdAt: Date
    var updatedAt: Date
}
```

**Color Palette:**  
`#EF4444 #F59E0B #FCD34D #10B981 #3B82F6 #6366F1 #8B5CF6 #EC4899 #14B8A6`

**Emoji Palette:**  
`["⚡️","🚀","🔥","🧠","🐢","😎","🍀","🎯","💎","🏁","📚","🕹️"]`

---

## 4) Persistence

- **Local:** via `AppStorage` for quick boot  
- **Cloud:** Firestore collection `profiles/{playerId}`  
- Merge logic on sign-in/out  
- Offline fallback handled seamlessly

---

## 5) UI & Flow

### 5.1 OnboardingEmojitarView
- Title: “Pick your vibe 👇”  
- Emoji grid + color palette  
- Live preview badge using `EmojitarBadge(size: .xxl, ring: true, glow: .subtle)`  
- Save button appears after both selections  
- VoiceOver labels for accessibility

### 5.2 EmojitarBadge
```swift
struct EmojitarBadge: View {
    enum Size { case xs, sm, md, lg, xl, xxl }
    var emoji: String
    var color: Color
    var size: Size
    var ring: Bool = false
    var glow: Bool = false
    var highlight: Bool = false
}
```
- Circular colored background with centered emoji  
- Optional ring/glow for highlighting correct answers  
- Uses dynamic foreground contrast

### 5.3 Multiplayer Integration
- **Lobby:** show player list with their Emojitars beside names  
- **Countdown:** central display of all participating players  
- **Round:** each question appears with every player’s badge beside their answer  
- **Scoreboard:** ranks players using their Emojitar as visual identity  
- **First Correct:** triggers pulse + glow + haptic feedback for the winner

---

## 6) Networking & Fairness

**Firestore structure:**
- `games/{gameId}/rounds/{roundId}`
  - `problem: {a:Int, b:Int}`
  - `state: "open"|"locked"`
  - `startedAt: serverTimestamp`
- `answers/{playerId}`
  - `value: Int`
  - `submittedAt: serverTimestamp`
  - `isCorrect: Bool`

Server functions resolve **first correct** via server timestamp.  
Client shows results once state changes to `"locked"`.

---

## 7) Animations & Haptics

- Selection: `.spring(response: 0.35, dampingFraction: 0.7)`  
- Correct answer highlight: glow + scale (1.0 → 1.12 → 1.0)  
- Haptic feedback on submit + correct events

---

## 8) Accessibility & Style

- Dynamic Type + VoiceOver labels for all emoji/color buttons  
- Auto-contrast ensures readability in dark/light mode  
- Scales smoothly on all iPhones (12 and newer)

---

## 9) Telemetry

Track:
- `emojitar_selected`
- `first_correct`
- `round_completed`
Payloads include emoji, color, and round timing data.

---

## 10) Error States

- Firestore failure → Toast: “Offline — local profile used.”  
- Missing profile → Force quick Emojitar picker  
- Invalid colorHex → fallback to default color

---

## 11) Testing

- Unit: data model, store behavior, tie-breaking logic  
- Snapshot: EmojitarBadge variants (sizes, glow, color contrast)  
- UI: onboarding flow, multiplayer rendering, winner highlight  

---

## 12) File Map

```
Sources/
  Identity/
    Emojitar.swift
    PlayerProfile.swift
    PlayerProfileStore.swift
  UI/
    Components/
      EmojitarBadge.swift
    Onboarding/
      OnboardingEmojitarView.swift
  Multiplayer/
    Models/
      GameModels.swift
    Views/
      LobbyView.swift
      CountdownView.swift
      RoundView.swift
      ScoreboardView.swift
    Services/
      SyncService.swift
      AnswerValidator.swift
  Utils/
    Color+Hex.swift
    AnalyticsClient.swift
Tests/
  IdentityTests/
  UITests/
  SnapshotTests/
```

---

## 13) Acceptance Criteria

- Onboarding requires emoji + color before gameplay  
- Emojitar persists locally and syncs via Firestore  
- Emojitar displays across all multiplayer views  
- First correct triggers animation + haptic feedback  
- Smooth performance at 60fps  
- Accessible, adaptive, and bug-free

---

## 14) Example Snippets

```swift
EmojitarBadge(
    emoji: "🧠",
    color: Color(hex: "#6366F1"),
    size: .xl,
    ring: true,
    glow: true
)
```

```swift
let profile = PlayerProfile(
    id: userId,
    displayName: name,
    emojitar: Emojitar(emoji: selectedEmoji, colorHex: selectedHex),
    createdAt: Date(),
    updatedAt: Date()
)
try await profileStore.save(profile)
```

---

## 15) Product Vision

This feature establishes **identity, presence, and emotional connection** in Turbo Tables.  
By giving every player a personalized emoji and color, even a short match feels personal and memorable — a light, joyful experience that makes math social.
