# Admin Two-Factor Authentication

The admin site enrolls a separate authenticator app for each administrator. Configure the owner, Andre, and Ella as individual accounts.

## Prepare the Accounts

Run these commands locally and give each person a different password when prompted:

```powershell
py -3 -m pip install -r AdminWebpage/requirements.txt
py -3 scripts/generate_admin_account.py --username owner
py -3 scripts/generate_admin_account.py --username andre
py -3 scripts/generate_admin_account.py --username ella
```

Each command prints one JSON entry. Combine the entries into `ADMIN_ACCOUNTS_JSON` for the Admin Render service:

```json
{
  "owner": {"password_hash": "..."},
  "andre": {"password_hash": "..."},
  "ella": {"password_hash": "..."}
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
