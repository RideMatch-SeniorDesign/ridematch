# Architecture — RideMatch

## 1) Overview
RideMatch includes:
- Rider mobile app
- Driver mobile app
- Admin web panel
- Shared backend API + database

## 2) High-Level Data Flow
Rider App  ─┐
            ├──> Backend API ───> Database
Driver App ─┘
Admin Web ─────> Backend API

## 3) Key Concepts
- **Matching:** swipe-based approve/reject (exact rule TBD: mutual swipe vs request/accept)
- **Driver verification:** admin approves driver before activation
- **Ride lifecycle:** requested → accepted → in_progress → completed (plus decline/cancel as needed)

## 4) Component Responsibilities
### Rider App
- account/login
- browse drivers + swipe
- request ride
- track driver location
- message/call (scope TBD)
- rate driver

### Driver App
- account/login + verification submission
- availability
- view/accept/decline requests
- send location pings
- message/call (scope TBD)
- rate rider

### Admin Web
- admin login
- verify/approve drivers
- optional: ban/unban users

### Backend API
- auth + roles
- matching logic + swipe records
- ride state machine
- location updates
- ratings
- admin endpoints

## 5) Technology Decisions (fill in)
- Mobile:  
- Backend:  
- Database:  
- Hosting:  
- Maps provider:  
- Realtime approach: Polling vs WebSockets

## 6) Security / Privacy Notes (minimum)
- Separate roles/permissions (rider/driver/admin)
- Protect sensitive driver verification fields
- Do not commit secrets; use env vars

## 7) Future Improvements (post-MVP)
- Better matching filters/preferences
- Push notifications
- More safety features
