# Security & Privacy Notes — RideMatch

## Roles & Access
- Rider: rider endpoints only
- Driver: driver endpoints only
- Admin: admin endpoints only (verification)

## Sensitive Data Rules
- Rider must NOT see driver license/verification documents
- Store secrets only in env vars
- Don’t log sensitive values

## Minimum Security Checklist
- Passwords hashed (never plain text)
- Auth tokens stored securely
- Input validation for key endpoints
- Rate limiting (optional)
