from __future__ import annotations

import argparse
import getpass
import json

from werkzeug.security import generate_password_hash


def main() -> None:
    parser = argparse.ArgumentParser(description="Generate one RideMatch admin password-hash entry.")
    parser.add_argument("--username", required=True)
    parser.add_argument("--password")
    args = parser.parse_args()

    password = args.password or getpass.getpass("Admin password: ")
    if not args.password:
        confirmation = getpass.getpass("Confirm admin password: ")
        if password != confirmation:
            raise SystemExit("Passwords do not match. No account entry was generated.")
    entry = {args.username: {"password_hash": generate_password_hash(password)}}
    print(json.dumps(entry))


if __name__ == "__main__":
    main()
