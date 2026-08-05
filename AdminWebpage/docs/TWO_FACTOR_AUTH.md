# Admin Two-Factor Authentication

The admin page requires a six-digit TOTP code only when `ADMIN_TOTP_SECRET` is configured.

## Enroll the Admin Authenticator

Run this command locally, then scan the generated PNG using an authenticator app:

```powershell
py -3 -m pip install -r AdminWebpage/requirements.txt
py -3 scripts/generate_admin_totp.py --username admin --output admin-totp-qr.png
```

Set the printed `ADMIN_TOTP_SECRET` and `ADMIN_TOTP_ISSUER` as Render environment variables for the admin service. Set `SESSION_COOKIE_SECURE=true` in production.

Do not commit the generated QR image or the TOTP secret. Store a recovery copy of the secret in your approved password manager.
