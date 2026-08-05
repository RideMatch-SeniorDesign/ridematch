from __future__ import annotations

import argparse
import getpass
import json
from pathlib import Path

import pyotp
import qrcode
from werkzeug.security import generate_password_hash


def main() -> None:
    parser = argparse.ArgumentParser(description="Generate a RideMatch admin TOTP enrollment QR code.")
    parser.add_argument("--username", required=True)
    parser.add_argument("--issuer", default="RideMatch Admin")
    parser.add_argument("--output", default="admin-totp-qr.png")
    parser.add_argument("--password")
    args = parser.parse_args()

    password = args.password or getpass.getpass("Admin password: ")
    secret = pyotp.random_base32()
    uri = pyotp.TOTP(secret).provisioning_uri(name=args.username, issuer_name=args.issuer)
    output_path = Path(args.output).resolve()
    qrcode.make(uri).save(output_path)

    account_entry = {
        args.username: {
            "password_hash": generate_password_hash(password),
            "totp_secret": secret,
        }
    }
    print(json.dumps(account_entry))
    print(f"ADMIN_TOTP_ISSUER={args.issuer}")
    print(f"QR code saved to: {output_path}")


if __name__ == "__main__":
    main()
