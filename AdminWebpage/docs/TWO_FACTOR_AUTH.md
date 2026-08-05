# Admin Two-Factor Authentication

The admin page supports separate password and TOTP credentials for each administrator. Configure the owner, Andre, and Ella as individual accounts.

## Enroll the Admin Authenticator

Run this command locally, then scan the generated PNG using an authenticator app:

```powershell
py -3 -m pip install -r AdminWebpage/requirements.txt
py -3 scripts/generate_admin_totp.py --username owner --output owner-totp-qr.png
py -3 scripts/generate_admin_totp.py --username andre --output andre-totp-qr.png
py -3 scripts/generate_admin_totp.py --username ella --output ella-totp-qr.png
```

Each command prints one JSON account entry. Combine the three entries into one `ADMIN_ACCOUNTS_JSON` value in the Admin Render service, for example:

```json
{
  "owner": {"password_hash": "...", "totp_secret": "..."},
  "andre": {"password_hash": "...", "totp_secret": "..."},
  "ella": {"password_hash": "...", "totp_secret": "..."}
}
```

Also set `ADMIN_TOTP_ISSUER=RideMatch Admin` and `SESSION_COOKIE_SECURE=true` in production.

Do not commit the generated QR image or the TOTP secret. Store a recovery copy of the secret in your approved password manager.
