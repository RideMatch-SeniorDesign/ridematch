# Questions Tracker — RideMatch (Team 2)

> Purpose: keep every question in one place, track who answered it, and record the final decision.

Legend: ✅ Answered | 🟡 Waiting | 🔴 Needs discussion

---

## A) Sponsor Questions
| ID | Question | Why it matters | Asked on | Status | Answer / Decision | Owner | Link to notes |
|----|----------|----------------|---------:|--------|-------------------|-------|--------------|
| S1 | Should matching be mutual swipe, or rider-request then driver-accept? | Defines core flow | | 🟡 | | | |
| S2 | What does “driver verification” mean for this project (docs, manual steps, etc.)? | Admin scope | | 🟡 | | | |
| S3 | Payments: real (Stripe test mode) or simulated? | Scope + risk | | 🟡 | | | |
| S4 | “Call through the app”: actual VoIP or just tap-to-call? | Complexity | | 🟡 | | | |
| S5 | Location updates: how real-time is required (every 1s/5s/10s)? | Tech decisions | | 🟡 | | | |

---

## B) Instructor / Requirements Questions
| ID | Question | Why it matters | Asked on | Status | Answer / Decision | Owner | Link |
|----|----------|----------------|---------:|--------|-------------------|-------|------|
| I1 | What are the required graded deliverables and exact due dates? | Planning | | 🔴 | | | |
| I2 | Any constraints on tools/frameworks we can use? | Tech stack | | 🟡 | | | |
| I3 | Is a simulated payment acceptable for the final demo? | Scope | | 🟡 | | | |

---

## C) Team Internal Questions
| ID | Question | Why it matters | Status | Decision | Owner | Link |
|----|----------|----------------|--------|----------|-------|------|
| T1 | Choose mobile framework: Flutter vs React Native | Affects all dev | 🔴 | | | |
| T2 | Realtime approach: polling vs WebSockets | Affects tracking | 🔴 | | | |
| T3 | Monorepo vs multi-repo (confirm) | Workflow | ✅ | Monorepo | | |

---

## D) “Parking Lot” (good ideas, not urgent)
| Idea | Why it’s cool | When to revisit |
|------|----------------|-----------------|
| SOS / safety features | Safety | After MVP spine |
| Trip sharing link | Safety | After MVP spine |
| Rider/driver preferences | Better matching | Sprint 5+ |

---

## E) Rules for using this tracker
- If a question affects architecture or scope → log it here **before** coding major pieces.
- Once answered → copy the final decision into the Decision Log (`docs/02_DECISION_LOG.md`).
