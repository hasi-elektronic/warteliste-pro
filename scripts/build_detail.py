#!/usr/bin/env python3
"""Deep inspection of Build 22's TestFlight state and tester assignments."""
import time, jwt, os, requests, json

KEY_ID = "X3J36XDY86"
ISSUER_ID = "f450133a-5308-4a08-9234-a7052b5190e9"
KEY_PATH = os.path.expanduser("~/.config/appstoreconnect-api/AuthKey_X3J36XDY86.p8")
BUILD_ID = "c1a543c7-1b4c-42b6-a08f-8c499bcdc172"
APP_ID = "6762089200"

def make_jwt():
    with open(KEY_PATH) as f:
        key = f.read()
    now = int(time.time())
    return jwt.encode(
        {"iss": ISSUER_ID, "iat": now, "exp": now + 600, "aud": "appstoreconnect-v1"},
        key, algorithm="ES256", headers={"kid": KEY_ID, "typ": "JWT"},
    )

def get(path, token, **params):
    r = requests.get(
        f"https://api.appstoreconnect.apple.com/v1{path}",
        headers={"Authorization": f"Bearer {token}"},
        params=params, timeout=20,
    )
    return r.status_code, (r.json() if r.ok else r.text)

token = make_jwt()

print("=== Build 22 full details ===")
s, b = get(f"/builds/{BUILD_ID}", token, include="app,appEncryptionDeclaration,individualTesters,betaGroups,buildBetaDetail,betaBuildLocalizations")
print(f"HTTP {s}")
if isinstance(b, dict):
    a = b["data"]["attributes"]
    print(f"  version       = {a.get('version')}")
    print(f"  processing    = {a.get('processingState')}")
    print(f"  expired       = {a.get('expired')}")
    print(f"  lifecycle     = {a.get('buildAudienceType')}")
    print(f"  min OS        = {a.get('minOsVersion')}")
    print(f"  uploaded      = {a.get('uploadedDate')}")
    print(f"  expirationDate= {a.get('expirationDate')}")
    print(f"  usesNonExemptEncryption = {a.get('usesNonExemptEncryption')}")
    rels = b["data"].get("relationships", {})
    print(f"  betaGroups    = {rels.get('betaGroups', {}).get('data')}")
    print(f"  individualTesters = {rels.get('individualTesters', {}).get('data')}")
    for inc in b.get("included", []):
        t = inc.get("type")
        if t == "buildBetaDetails":
            aa = inc.get("attributes", {})
            print(f"  internalBuildState = {aa.get('internalBuildState')}")
            print(f"  externalBuildState = {aa.get('externalBuildState')}")
            print(f"  autoNotify   = {aa.get('autoNotifyEnabled')}")
        if t == "appEncryptionDeclarations":
            aa = inc.get("attributes", {})
            print(f"  encryption decl  = {aa}")

print()
print("=== All Internal testers for this app ===")
# Internal testers are App Store Connect users with access
s, t = get("/users", token, **{"filter[visibleApps]": APP_ID, "limit": 100})
print(f"HTTP {s}")
if isinstance(t, dict):
    for u in t.get("data", []):
        a = u["attributes"]
        print(f"  {a.get('username'):40s} roles={a.get('roles')}")

print()
print("=== Beta Testers (external style) ===")
s, t = get("/betaTesters", token, **{"filter[apps]": APP_ID, "limit": 200})
if isinstance(t, dict):
    for bt in t.get("data", []):
        a = bt["attributes"]
        print(f"  {a.get('email'):40s} invite={a.get('inviteType')}  state={a.get('state')}")
