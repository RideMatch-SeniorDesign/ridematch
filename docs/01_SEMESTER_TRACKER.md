# RideMatch — Semester Tracker (Team 2)

## 1) Project Info
**Project:** RideMatch (Rider app + Driver app + Admin web + Backend)  
**Team Members:**  
-  Ella Potter
-  Andre McGee
-  Michael Meves

**Sponsor: Ebrahim Mohamad and Rafael Rangel de la Tejera**  
**Advisor/Instructor: Najeeb Najeeb and Yang Liu**  
**Repo:** [<https://github.com/RideMatch-SeniorDesign/ridematch>](https://github.com/RideMatch-SeniorDesign/ridematch)  
**GitHub Project Board:** [<https://github.com/orgs/RideMatch-SeniorDesign/projects/1>](https://github.com/orgs/RideMatch-SeniorDesign/projects/1)

---


## 2) Deliverables & Deadlines

| Date | Deliverable | Owner | Status |
|------|-------------|-------|--------|
| 1/20/2026 | Set up GitHub | Ella Potter | Complete |
| 1/23/2026 | Set up Initial Project | Michael Meves | Complete |
| 1/28/2026 | Build low-fi UIs | Andre McGee | Complete |
|  |  |  |  |
| 2/3/2026 | Implement User Registration | Andre McGee | Backlog |
| 2/3/2026 | Set-Up Database Schema | Michael Meves | Backlog |
| 2/9/2026 | Implement Basic Admin Login | Ella Potter | Backlog |
|  |  |  |  |
| 2/16/2026 | Implement Swipe Feature | Michael Meves | Backlog |
| 2/16/2026 | Implement Finding Drivers | Andre McGee | Backlog |
| 2/23/2026 | Add Matching Rules | Ella Potter | Backlog |
|  |  |  |  |
| 3/3/2026 | Implement Flow of Rides | Ella Potter | Backlog |
| 3/3/2026 | Integrate Maps/Routes/Tracking | Michael Meves | Backlog |
| 3/12/2026 | Add Ride History | Andre McGee | Backlog |
|  |  |  |  |
| 3/17/2026 | Implement Rating/Messaging | Andre McGee | Backlog |
| 3/20/2026 | Implement Admin Dashboard | Ella Potter | Backlog |
| 3/25/2026 | Add Basic Notifications | Michael Meves | Backlog |
|  |  |  |  |
| 3/31/2026 | Integrate Payment Storage | Michael Meves | Backlog |
| 3/31/2026 | Add Logging for Events | Ella Potter | Backlog |
| 4/7/2026 | Review Authentication & Auth | Andre McGee | Backlog |
|  |  |  |  |
| 4/14/2026 | End-to-End Testing | Ella Potter | Backlog |
| 4/17/2026 | Refine UI/UX | Andre McGee | Backlog |
| 4/20/2026 | Collect & Fix All Bugs | Michael Meves | Backlog |
|  |  |  |  |
| 4/25/2026 | Finalize Documentation | All | Backlog |
| 4/25/2026 | Final Verifications | All | Backlog |
| 4/29/2026 | Prepare Presentations | All | Backlog |


---

## 3) Sprint Plan Overview

## 3) Sprint Plan Overview

### Sprint 1: 1/20/2026 - 2/2/2026
**Sprint Goal:**  
Stand up the project foundation (repo + working scaffold + low-fi UI flows) so development can move fast starting Sprint 2.

**Planned Features:**  
- **Set up GitHub** *(Owner: Ella Potter | Status: Complete)*  
  - Create repo + add all teammates  
  - Add branch protections + basic branching rules (feature branches → PR → review → merge)  
  - Add issue labels + milestones for Sprint 1–8  
  - Add basic README (project overview + how to run)  
- **Set up Initial Project** *(Owner: Michael Meves | Status: Complete)*  
  - Create initial app scaffold (Rider, Driver, Admin structure started)  
  - Confirm local dev setup instructions work (clone → install → run)  
  - Add basic folder structure + placeholder routes/pages  
- **Build low-fi UIs** *(Owner: Andre McGee | Status: Complete)*  
  - Low-fi screens for Rider (register/login, swipe/match, ride flow)  
  - Low-fi screens for Driver (login, accept/deny, ride in-progress)  
  - Low-fi screens for Admin (login, dashboard overview)

**Definition of Done:**  
- Repo is accessible to the whole team and protected branches are set  
- Project runs locally with clear setup/run steps in the README  
- Low-fi UI flows cover Rider, Driver, and Admin core screens and are ready to implement

---

### Sprint 2: 2/3/2026 - 2/15/2026
**Sprint Goal:**  
Enable user onboarding + admin access with a working database foundation.

**Planned Features:**  
- **Implement User Registration** *(Owner: Andre McGee | Status: Backlog)*  
  - Create registration UI + validation  
  - Store user profile info in DB  
- **Set-Up Database Schema** *(Owner: Michael Meves | Status: Backlog)*  
  - Define core tables/models (Users, Roles, Riders, Drivers, Rides, Matches)  
  - Migrations run cleanly and seed data exists for testing  
- **Implement Basic Admin Login** *(Owner: Ella Potter | Status: Backlog)*  
  - Admin login page + session/auth handling  
  - Restrict admin-only routes to admin accounts

**Definition of Done:**  
- Users can register and persist data successfully  
- Database schema supports core system entities and is documented  
- Admin can log in and reach an admin-only page with access control enforced

---

### Sprint 3: 2/16/2026 - 3/2/2026
**Sprint Goal:**  
Deliver the first working matching experience: swipe + discovery + basic rules.

**Planned Features:**  
- **Implement Swipe Feature** *(Owner: Michael Meves | Status: Backlog)*  
  - Swipe UI records like/dislike actions  
  - Save swipe results in the database  
- **Implement Finding Drivers** *(Owner: Andre McGee | Status: Backlog)*  
  - Rider can view a list/queue of available drivers (or match candidates)  
  - Pull results from DB or seeded dataset  
- **Add Matching Rules** *(Owner: Ella Potter | Status: Backlog)*  
  - Define rule logic for what qualifies as a match  
  - Document matching criteria in the wiki

**Definition of Done:**  
- Swipe interactions work consistently and save results  
- Candidate discovery works using stored/seeded data  
- Matching rules are implemented + documented and can trigger a match outcome

---

### Sprint 4: 3/3/2026 - 3/16/2026
**Sprint Goal:**  
Turn matches into real rides with a basic ride lifecycle and maps support.

**Planned Features:**  
- **Implement Flow of Rides** *(Owner: Ella Potter | Status: Backlog)*  
  - Ride request → accept → in progress → complete/cancel flow  
  - Ride status updates stored in DB  
- **Integrate Maps/Routes/Tracking** *(Owner: Michael Meves | Status: Backlog)*  
  - Map display for pickup/dropoff + route basics  
  - (Optional) basic tracking updates if supported  
- **Add Ride History** *(Owner: Andre McGee | Status: Backlog)*  
  - Rider and driver can view past rides  
  - Ride details shown (date, status, basic info)

**Definition of Done:**  
- Ride lifecycle is functional end-to-end and persists statuses  
- Maps/routes integration works at a basic demonstrable level  
- Ride history displays completed rides correctly for each role

---

### Sprint 5: 3/17/2026 - 3/30/2026
**Sprint Goal:**  
Improve product usability and trust: messaging, ratings, admin visibility, and notifications.

**Planned Features:**  
- **Implement Rating/Messaging** *(Owner: Andre McGee | Status: Backlog)*  
  - Messaging between rider/driver within a ride context  
  - Post-ride rating submission stored in DB  
- **Implement Admin Dashboard** *(Owner: Ella Potter | Status: Backlog)*  
  - Admin overview of users + rides + statuses  
  - Basic metrics (counts, active rides, etc.)  
- **Add Basic Notifications** *(Owner: Michael Meves | Status: Backlog)*  
  - Notifications for key events (match, ride accepted, completed, cancelled)  
  - Implement as in-app or email (whichever your team chose)

**Definition of Done:**  
- Ratings/messages work and persist reliably  
- Admin dashboard shows core system info and is access-controlled  
- Notifications trigger for major events and are visible/testable

---

### Sprint 6: 3/31/2026 - 4/13/2026
**Sprint Goal:**  
Add reliability features: payment storage, stronger auth review, and logging for debugging + demo readiness.

**Planned Features:**  
- **Integrate Payment Storage** *(Owner: Michael Meves | Status: Backlog)*  
  - Store payment-related records (not necessarily real processing)  
  - Tie payments to rides/trips in DB  
- **Review Authentication & Auth** *(Owner: Andre McGee | Status: Backlog)*  
  - Verify role permissions (Rider/Driver/Admin)  
  - Fix any session/security gaps and document decisions  
- **Add Logging for Events** *(Owner: Ella Potter | Status: Backlog)*  
  - Log key events (login, matches, ride status changes, payment events)  
  - Ensure logs are readable + consistent

**Definition of Done:**  
- Payment records are stored and linked to rides  
- Auth is reviewed, roles work correctly, and key issues are fixed  
- Logging exists for critical flows and helps debug problems quickly

---

### Sprint 7: 4/14/2026 - 4/27/2026
**Sprint Goal:**  
Stabilize the system for final demo through testing, bug fixes, and UI polish.

**Planned Features:**  
- **End-to-End Testing** *(Owner: Ella Potter | Status: Backlog)*  
  - Write and run a demo checklist for all major flows  
  - Track test results and failures  
- **Collect & Fix All Bugs** *(Owner: Michael Meves | Status: Backlog)*  
  - Fix high-priority bugs first  
  - Document known issues if any remain  
- **Refine UI/UX** *(Owner: Andre McGee | Status: Backlog)*  
  - Clean up layouts, navigation, and usability  
  - Improve error messages and empty states

**Definition of Done:**  
- Core demo flow works without hacks or workarounds  
- Most critical bugs are resolved and remaining issues are documented  
- UI is consistent and presentation-ready

---

### Sprint 8: 4/25/2026 - 5/6/2026
**Sprint Goal:**  
Finalize deliverables: documentation, final verification, and presentation/demo readiness.

**Planned Features:**  
- **Finalize Documentation** *(Owner: All | Status: Backlog)*  
  - Complete README + wiki pages + architecture notes  
  - Add “How to run demo” instructions  
- **Prepare Presentations** *(Owner: All | Status: Backlog)*  
  - Slides + demo script + team speaking parts  
  - Practice run-through  
- **Final Verifications** *(Owner: All | Status: Backlog)*  
  - Final checklist against requirements  
  - Confirm everything builds + runs cleanly

**Definition of Done:**  
- Docs are complete and accurate (setup, arch


---

## 4) Weekly Log 

### Week 1 (2026-01-19 to 2026-01-26)
**What we completed:**
- Met with sponsor to discuss any initial project questions
- Finalized Project Proposal
- Set up Github and initial files

**What we started:**
- Began thinking of initial questions for project deliverables
- Started working on making low-fi sketches of UIs

**What changed / decisions made:**
- Decided what coding language to use

### Week 2 (2026-01-26 to 2026-02-02)
**What we completed:**
- Finished low-fi diagrams
- Came up with initial project questions for sponsor

**What we started:**
- Began working on creating all project requirements in github projects

---

## 5) Meeting Notes

- **YYYY-MM-DD**
  - Attendees:  
  - Key answers:  
  - Decisions:  
  - Action items (owner + due date):
    -  

