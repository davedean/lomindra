# Project Plan: Lomindra (Apple Reminders <-> Vikunja Sync)

## Goal
Build a two-way sync between Apple Reminders and Vikunja, starting with a single list and expanding to full account coverage. The initial focus is on data model compatibility and API capabilities, not on a specific runtime.

## Phase 0: Discovery and Data Model Mapping
- Collect core field lists for Apple Reminders and Vikunja.
- Define a common task/list schema with types and constraints.
- Document lossy mappings and unsupported fields.
- Decide how to represent:
  - due dates (date-only vs date-time)
  - completion
  - recurrence
  - priorities
  - tags/labels
  - notes (URLs, rich text)
  - subtasks/checklists
  - attachments

Deliverable: `docs/common-schema.md` and a feature compatibility table.

## Phase 1: Single-List Sync Design (done)
- Define sync scope: one list on each side.
- Choose a conflict policy (initially last-write-wins).
- Define identity mapping strategy (mapping table or external IDs).
- Define change detection strategy:
  - how to detect updates
  - how to detect deletions
  - how to store cursors/timestamps
- Define MVP mapping policies:
  - priority mapping between Reminders (1/5/9) and Vikunja integer scale
  - date-only handling with round-trip preservation via metadata
  - relative alarm base defaulting (due vs start)
- Choose sync metadata storage (SQLite recommended).
- Define sync loop (push/pull order, retry strategy).

Deliverable: `docs/sync-design.md`. (done)

## Phase 2: Offline Translation Prototype
- Create a set of representative sample tasks.
- Draft transformation rules:
  - Reminders -> Common -> Vikunja
  - Vikunja -> Common -> Reminders
- Validate edge cases with sample tasks.

Deliverable: `docs/translation-rules.md` and sample JSON fixtures.

## Phase 3: API Capability Spike (done)
- Verify Apple Reminders API behavior (read/write/filters).
- Verify Vikunja API behavior (read/write/filters).
- Confirm that required fields are supported as expected.
- Update compatibility table with empirical findings.

Deliverable: `docs/api-notes.md`. (done)

## Phase 4: MVP Sync Implementation (Single List)
- Build a minimal two-way sync with create/update/delete.
- Implement conflict handling policy.
- Persist sync state and mapping.
- Add minimal logging and dry-run support.
- Support alarms and basic recurrence.
- Add deterministic seed data for repeatable validation.

Deliverable: working MVP sync for one list.

## Phase 5: Multi-List Support + Selectable Lists
- Support multiple lists/projects. (done)
- Add configuration to select lists to sync (including an "all lists" option). (done)
- Improve conflict handling and reporting. (done)
- Add configuration UI or settings format. (done)
- Prepare for iOS app integration. (done)

Deliverable: multi-list sync with selectable lists + roadmap for iOS app.

## Open Questions
- Preferred storage for sync state and mapping (local DB vs files).
- Use of reminders metadata fields for external IDs.
- Recurrence mapping compatibility.
- Handling of completed tasks and tombstones.
- List selection storage (per-device config vs shared settings).

## Phase 6: iOS MVP (Single Device)
- Wrap sync engine in a minimal iOS app target. (done)
- Auth flow: user/pass -> JWT -> API token -> Keychain. (done)
- List selection UI (single or all, with confirmation). (done)
- Manual sync button + dry-run preview + summary. (done)
- iOS app launches in simulator and logs in successfully. (done)
- Dry run/apply buttons behave correctly (tap hit-testing fix). (done)
- Allow limited app usage without Vikunja sign-in; replace Vikunja-backed screens with a "sign in to Vikunja" prompt and disable actions clearly.
- Hide Sign Out behind a settings menu (gear or hamburger) to avoid accidental sign-out.
- Consider removing Dry Run button for most users; keep it as a debug-only option if needed.
  - Status: app is usable without sign-in, sign-in prompts added, Sign Out moved into settings menu, Dry Run now debug-only. (done)

Deliverable: working iOS MVP with manual sync.

## Phase 7: iOS Reliability
- Background sync (BGAppRefreshTask; BGProcessingTask if needed later).
- Conflict review UI with per-conflict resolution. (done)
- Error handling, retry/backoff, and safe logging.
- Simplify sync output: "Sync complete" on success; hide conflict log links unless conflicts exist. (done)
- When sync fails, prefer user-focused error summaries and optionally provide a "request support" action that shares a redacted log.

Deliverable: reliable sync with conflict review.

## Phase 8: Distribution/Polish
- Onboarding + permissions prompts.
- Settings export/import + diagnostics.
- Release checklist + small beta distribution plan.
- Add a Feedback option that opens an email draft.
- Add a GitHub repo link.

Deliverable: beta-ready iOS app.
