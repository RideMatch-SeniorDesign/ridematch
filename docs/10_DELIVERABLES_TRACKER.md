# Deliverables & Requirements Tracker — RideMatch (Team 2)

> Purpose: single source of truth for what we must deliver, by when, and how we’ll prove it works.

---

## A) Deliverables Calendar
| Due Date | Deliverable | Owner | Status (Not started / In progress / Done) | Evidence (Link) |
|---------:|-------------|-------|-------------------------------------------|-----------------|
|          | Proposal (final) |  |  |  |
|          | Sprint 1 demo |  |  |  |
|          | Midterm demo/review |  |  |  |
|          | Final demo |  |  |  |
|          | Final report |  |  |  |
|          | Poster / slides |  |  |  |

> Tip: Put links in “Evidence” to PRs, releases, demo videos, or screenshots.

---

## B) Requirement Status Dashboard (MVP)
Legend: ✅ Done | 🟡 In progress | 🔴 Not started | ⚪ Deferred

| ID | Requirement | Priority | Status | Owner | How we will validate | Link to issue(s) / PR(s) |
|----|-------------|----------|--------|-------|----------------------|---------------------------|
| R2 | Rider/Driver account creation | High | 🔴 |  | Create accounts in demo; saved in DB | |
| R3 | Login/authentication | High | 🔴 |  | Login + access protected screens | |
| R4 | Swipe approve/reject for matching | High | 🔴 |  | Swipe recorded; match state changes | |
| R5 | Driver accept/decline ride request | High | 🔴 |  | Driver sees request + accepts/declines | |
| R6 | Ride lifecycle (request→accept→in progress→complete) | High | 🔴 |  | Status transitions logged + visible | |
| R7 | Real-time driver location tracking | High | 🔴 |  | Rider sees driver move on map | |
| R8 | Message/call between rider & driver | Med | 🔴 |  | Send message / trigger call action | |
| R9 | Message/call between driver & rider | Med | 🔴 |  | Send message / trigger call action | |
| R10 | Rider rates driver | Med | 🔴 |  | Rating stored + affects average | |
| R11 | Driver rates rider | Med | 🔴 |  | Rating stored + affects average | |
| R12 | Admin portal login | High | 🔴 |  | Admin can access admin-only routes | |
| R13 | Admin verifies drivers before activation | High | 🔴 |  | Pending→approved→active flow works | |

---

## C) Optional / Stretch Requirements
| ID | Optional Requirement | Priority | Status | Notes / Condition to include |
|----|----------------------|----------|--------|------------------------------|
| OR1 | Driver preferences filtering | Low | ⚪ | Only if matching works early |
| OR4 | Ratings include comments | Low | ⚪ | After core ratings are stable |
| OR7 | Admin ban/unban users | Med | ⚪ | If verification is done early |

---

## D) Non-Functional / Constraints Checklist
| Constraint | Status | Notes / Proof |
|-----------|--------|---------------|
| Privacy: Rider cannot access sensitive driver verification details | 🔴 | |
| Payment: Rider cannot deny payment (approach TBD) | 🔴 | |
| Performance: matching fast enough for demo | 🔴 | |
| Reliability: core flows don’t crash in demo | 🔴 | |

---

## E) Definition of Done (Project-Level)
A requirement is marked ✅ Done only if:
- Acceptance criteria are met
- Verified by demo steps or test evidence
- Linked issue closed and PR merged to `main`
- Documentation updated (if needed)

---

## F) Demo Validation Scripts (copy/paste for demos)
### Demo Script — MVP Spine
1. Create rider and driver accounts
2. Admin approves driver
3. Rider swipes and matches a driver
4. Rider requests ride, driver accepts
5. Rider sees real-time driver location
6. Complete ride
7. Rider & driver rate each other
8. (Optional) message/call flow
