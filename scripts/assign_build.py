#!/usr/bin/env python3
"""Assign the latest build to the hasi internal TestFlight group."""
import time, jwt, os, requests

KEY_ID = "X3J36XDY86"
ISSUER_ID = "f450133a-5308-4a08-9234-a7052b5190e9"
KEY_PATH = os.path.expanduser("~/.config/appstoreconnect-api/AuthKey_X3J36XDY86.p8")

GROUP_ID = "dfd27c63-3e70-4e1a-a59b-9d93aa7a529e"  # hasi internal
BUILD_ID = "c1a543c7-1b4c-42b6-a08f-8c499bcdc172"  # Build 22

def make_jwt():
    with open(KEY_PATH, "r") as f:
        key = f.read()
    now = int(time.time())
    return jwt.encode(
        {"iss": ISSUER_ID, "iat": now, "exp": now + 600, "aud": "appstoreconnect-v1"},
        key, algorithm="ES256", headers={"kid": KEY_ID, "typ": "JWT"},
    )

token = make_jwt()
r = requests.post(
    f"https://api.appstoreconnect.apple.com/v1/betaGroups/{GROUP_ID}/relationships/builds",
    headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json"},
    json={"data": [{"type": "builds", "id": BUILD_ID}]},
    timeout=20,
)
print(f"Status: {r.status_code}")
print(f"Body: {r.text or '(empty)'}")
