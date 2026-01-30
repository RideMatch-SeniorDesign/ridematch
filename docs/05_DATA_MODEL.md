# Data Model Notes — RideMatch

## Entities (Draft)
- User (id, role, email, password_hash, created_at)
- RiderProfile (user_id, name, rating_avg, ...)
- DriverProfile (user_id, name, vehicle_info, verification_status, rating_avg, ...)
- Swipe (id, rider_id, driver_id, decision, created_at)
- Match (id, rider_id, driver_id, created_at)
- Ride (id, rider_id, driver_id, status, pickup, dropoff, timestamps, cost)
- Rating (id, ride_id, rater_id, ratee_id, stars, comment?)
- LocationPing (id, ride_id, driver_id, lat, lng, created_at)

## Enums
- verification_status: pending / approved / rejected
- ride_status: requested / accepted / in_progress / completed / canceled / declined

## Notes / Open Questions
- Do we need a Match table or can we infer from swipe decisions?
- Store full pickup/dropoff or just coordinates?
