# Admin Two-Factor Authentication

The admin site enrolls a separate authenticator app for each administrator. Configure the owner, Andre, and Ella as individual accounts.

## Prepare the Accounts

Run these commands locally and give each person a different password when prompted:

```powershell
py -3 -m pip install -r AdminWebpage/requirements.txt
py -3 scripts/generate_admin_account.py --username owner --email owner@example.com
py -3 scripts/generate_admin_account.py --username andre --email andre@example.com
py -3 scripts/generate_admin_account.py --username ella --email ella@example.com
```

Each command prints one JSON entry. Combine the entries into `ADMIN_ACCOUNTS_JSON` for the Admin Render service:

```json
{
  "owner": {"password_hash": "...", "email": "owner@example.com"},
  "andre": {"password_hash": "...", "email": "andre@example.com"},
  "ella": {"password_hash": "...", "email": "ella@example.com"}
}
```

Generate an encryption key locally:

```powershell
py -3 -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())"
```

Add these Render environment variables before the enrollment deployment:

```text
ADMIN_ACCOUNTS_JSON=<combined JSON>
ADMIN_MFA_ENCRYPTION_KEY=<generated key>
ADMIN_TOTP_ISSUER=RideMatch Admin
ADMIN_2FA_ENROLLMENT_OPEN=true
SESSION_COOKIE_SECURE=true
```

After deployment, each person signs in to the website using their own password, scans the QR code shown on the setup page, and confirms the six-digit code. Once all three accounts are enrolled, set `ADMIN_2FA_ENROLLMENT_OPEN=false` and deploy again.

Do not commit passwords, encryption keys, QR images, or TOTP secrets. Store recovery copies in your approved password manager.

## Password Reset Email

Add an email address to every `ADMIN_ACCOUNTS_JSON` entry, then configure the same SMTP settings used by admin notifications. Enable the reset flow only after SMTP has been tested:

```text
ADMIN_PASSWORD_RESET_ENABLED=true
ADMIN_PASSWORD_RESET_MINUTES=30
ENABLE_EMAIL_NOTIFICATIONS=true
SMTP_HOST=<your SMTP host>
SMTP_PORT=587
SMTP_USERNAME=<your SMTP username>
SMTP_PASSWORD=<your SMTP password or app password>
SMTP_USE_TLS=true
FROM_EMAIL=<verified sender address>
```

Administrators use **Forgot your password?** on the login page. Reset links are single-use and expire after the configured time. The replacement password is stored securely in the database, so do not overwrite `ADMIN_ACCOUNTS_JSON` after a reset. Two-factor authentication remains required at sign-in.
