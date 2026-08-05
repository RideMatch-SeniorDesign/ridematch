from __future__ import annotations

import argparse
from pathlib import Path

import pyotp
import qrcode


def main() -> None:
    parser = argparse.ArgumentParser(description="Generate a RideMatch admin TOTP enrollment QR code.")
    parser.add_argument("--username", required=True)
    parser.add_argument("--issuer", default="RideMatch Admin")
    parser.add_argument("--output", default="admin-totp-qr.png")
    args = parser.parse_args()

    secret = pyotp.random_base32()
    uri = pyotp.TOTP(secret).provisioning_uri(name=args.username, issuer_name=args.issuer)
    output_path = Path(args.output).resolve()
    qrcode.make(uri).save(output_path)

    print(f"ADMIN_TOTP_SECRET={secret}")
    print(f"ADMIN_TOTP_ISSUER={args.issuer}")
    print(f"QR code saved to: {output_path}")


if __name__ == "__main__":
    main()
