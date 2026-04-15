#!/usr/bin/env python3
"""Upload an AAB to a Google Play track via the Play Developer API.

Usage:
    upload_to_play.py <aab_path> [--track internal] [--status draft]

Defaults to the internal track and a draft release. The release notes are
read from CHANGELOG_LATEST.txt next to this script if present.
"""
import argparse
import os
import sys
from pathlib import Path

from googleapiclient.discovery import build
from googleapiclient.http import MediaFileUpload
from google.oauth2 import service_account

PACKAGE_NAME = "com.hasielektronic.warteliste_pro"
KEY_FILE = os.path.expanduser("~/.config/play-publisher/warteliste-pro-key.json")
SCOPES = ["https://www.googleapis.com/auth/androidpublisher"]


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("aab", type=Path, help="Path to .aab")
    parser.add_argument("--track", default="internal",
                        choices=["internal", "alpha", "beta", "production"])
    parser.add_argument("--status", default="draft",
                        choices=["draft", "completed", "inProgress", "halted"])
    parser.add_argument("--notes", default="",
                        help="Release notes (de-DE). Overrides CHANGELOG_LATEST.txt")
    args = parser.parse_args()

    if not args.aab.exists():
        sys.exit(f"AAB not found: {args.aab}")

    notes = args.notes
    if not notes:
        changelog = Path(__file__).parent / "CHANGELOG_LATEST.txt"
        if changelog.exists():
            notes = changelog.read_text().strip()

    creds = service_account.Credentials.from_service_account_file(
        KEY_FILE, scopes=SCOPES)
    service = build("androidpublisher", "v3", credentials=creds)
    edits = service.edits()

    print(f"Creating edit for {PACKAGE_NAME}...")
    edit = edits.insert(packageName=PACKAGE_NAME, body={}).execute()
    edit_id = edit["id"]

    print(f"Uploading {args.aab} ({args.aab.stat().st_size // 1024} KB)...")
    media = MediaFileUpload(str(args.aab),
                            mimetype="application/octet-stream",
                            resumable=True)
    bundle = edits.bundles().upload(
        editId=edit_id, packageName=PACKAGE_NAME, media_body=media).execute()
    version_code = bundle["versionCode"]
    print(f"  uploaded versionCode={version_code} sha1={bundle.get('sha1')}")

    release = {
        "name": f"Build {version_code}",
        "versionCodes": [str(version_code)],
        "status": args.status,
    }
    if notes:
        release["releaseNotes"] = [{"language": "de-DE", "text": notes}]

    print(f"Assigning to track '{args.track}' (status={args.status})...")
    edits.tracks().update(
        editId=edit_id, packageName=PACKAGE_NAME, track=args.track,
        body={"releases": [release]}).execute()

    print("Committing edit...")
    edits.commit(editId=edit_id, packageName=PACKAGE_NAME).execute()
    print(f"Done. versionCode {version_code} on '{args.track}' ({args.status}).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
