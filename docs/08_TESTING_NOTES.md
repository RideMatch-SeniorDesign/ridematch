# Testing Notes — RideMatch

## 1) Testing Goals (MVP)
- Catch breaking changes early
- Ensure core ride flow works end-to-end
- Ensure role-based access (rider/driver/admin) is correct

## 2) Test Types
### Backend
- Unit tests: auth, matching logic, ride state transitions
- API tests: endpoint responses + error cases

### Apps (Rider/Driver)
- Smoke tests: login, key screens load
- Manual test scripts for demo

### Admin Web
- Smoke tests: login + verification workflow

## 3) Definition of Done (Testing)
A feature is “done” when:
- Acceptance criteria pass
- At least one validation method exists:
  - unit test OR API test OR documented manual test steps (for early MVP)

## 4) Manual Test Scripts (MVP Spine)
1. Create rider + driver
2. Admin approves driver
3. Rider swipes to match
4. Rider requests ride
5. Driver accepts
6. Rider sees driver location update
7. Driver completes ride
8. Both rate each other

## 5) Where test evidence lives
- Link PRs + screenshots/video in `10_DELIVERABLES_REQUIREMENTS_TRACKER.md`
