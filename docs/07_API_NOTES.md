# API Notes — RideMatch

> This is a living draft. Update as endpoints become real.

## Conventions
- Base URL: `/api`
- Auth: (JWT / session) TBD
- Standard response format (recommended):
  - `{ "data": ..., "error": null }` or `{ "data": null, "error": { "code": "...", "message": "..." } }`

---

## Auth
### POST /auth/register
**Purpose:** Create rider/driver account  
**Body:** `{ role, email, password, ... }`  
**Returns:** user + token/session

### POST /auth/login
### POST /auth/logout
### GET /me

---

## Admin: Driver Verification
### GET /admin/drivers/pending
### POST /admin/drivers/{driverId}/approve
### POST /admin/drivers/{driverId}/reject

---

## Matching / Swipes
### GET /drivers/candidates
**Returns:** list of driver cards for rider swipe feed

### POST /swipes
**Body:** `{ riderId, driverId, decision: "approve"|"reject" }`

### GET /matches
**Returns:** matched drivers for a rider (or matched riders for a driver)

---

## Ride Lifecycle
### POST /rides/request
**Body:** `{ riderId, driverId, pickup, dropoff }`

### POST /rides/{rideId}/accept
### POST /rides/{rideId}/decline
### POST /rides/{rideId}/start
### POST /rides/{rideId}/complete
### GET /rides/{rideId}

---

## Location
### POST /location/update
**Body:** `{ rideId, lat, lng, timestamp }`

### GET /location/{rideId}

---

## Messaging (scope TBD)
### POST /messages
### GET /messages/thread/{rideId}

---

## Ratings
### POST /ratings
**Body:** `{ rideId, raterId, rateeId, stars, comment? }`

---

## Open Questions
- Matching rule: mutual swipe vs rider request + driver accept
- Realtime: polling interval vs WebSockets
- Payments: real provider vs simulated
