#!/usr/bin/env python3
"""Query App Store Connect API for TestFlight build + group status."""
import time
import jwt
import os
import requests

KEY_ID = "X3J36XDY86"
ISSUER_ID = "f450133a-5308-4a08-9234-a7052b5190e9"
KEY_PATH = os.path.expanduser("~/.config/appstoreconnect-api/AuthKey_X3J36XDY86.p8")
APP_ID = "6762089200"

def make_jwt():
    with open(KEY_PATH, "r") as f:
        key = f.read()
    now = int(time.time())
    token = jwt.encode(
        {
            "iss": ISSUER_ID,
            "iat": now,
            "exp": now + 1200,
            "aud": "appstoreconnect-v1",
        },
        key,
        algorithm="ES256",
        headers={"kid": KEY_ID, "typ": "JWT"},
    )
    return token

def get(path, token, **params):
    r = requests.get(
        f"https://api.appstoreconnect.apple.com/v1{path}",
        headers={"Authorization": f"Bearer {token}"},
        params=params,
        timeout=20,
    )
    if not r.ok:
        print(f"ERROR {r.status_code}: {r.text[:400]}")
        r.raise_for_status()
    return r.json()

def main():
    token = make_jwt()

    print("=" * 60)
    print("BUILDS (last 5)")
    print("=" * 60)
    builds = get(
        f"/builds",
        token,
        **{
            "filter[app]": APP_ID,
            "sort": "-uploadedDate",
            "limit": 5,
            "include": "betaBuildLocalizations,preReleaseVersion",
        },
    )
    for b in builds.get("data", []):
        a = b["attributes"]
        print(f"  Build {a.get('version')}  "
              f"processingState={a.get('processingState')}  "
              f"uses-encryption={a.get('usesNonExemptEncryption')}  "
              f"expired={a.get('expired')}  "
              f"uploaded={a.get('uploadedDate')}")
        print(f"    id={b['id']}")

    # Take the latest build
    latest = builds["data"][0]
    build_id = latest["id"]

    print()
    print("=" * 60)
    print("BETA GROUPS (all)")
    print("=" * 60)
    groups = get(
        f"/betaGroups",
        token,
        **{
            "filter[app]": APP_ID,
            "include": "betaTesters,builds",
            "limit": 50,
        },
    )
    for g in groups.get("data", []):
        a = g["attributes"]
        rels = g.get("relationships", {})
        nb_testers = len(rels.get("betaTesters", {}).get("data", []))
        nb_builds = len(rels.get("builds", {}).get("data", []))
        print(f"  {a.get('name'):35s} "
              f"internal={a.get('isInternalGroup')}  "
              f"testers={nb_testers}  "
              f"builds={nb_builds}  "
              f"id={g['id']}")
        # list builds in group
        build_ids = [d["id"] for d in rels.get("builds", {}).get("data", [])]
        if build_ids:
            for bid in build_ids:
                marker = "← THIS IS BUILD 22" if bid == build_id else ""
                print(f"      has build id={bid} {marker}")

    print()
    print("=" * 60)
    print(f"BUILD 22 ({build_id}) → which groups?")
    print("=" * 60)
    r = get(f"/builds/{build_id}/relationships/betaGroups", token)
    bg = r.get("data", [])
    if not bg:
        print("  ❌ NICHT in any beta group!")
    else:
        print(f"  assigned to {len(bg)} group(s):")
        for x in bg:
            # look up name
            for g in groups["data"]:
                if g["id"] == x["id"]:
                    print(f"    - {g['attributes']['name']}")
                    break

    print()
    print("=" * 60)
    print("BETA TESTERS (all)")
    print("=" * 60)
    testers = get(
        f"/betaTesters",
        token,
        **{
            "filter[apps]": APP_ID,
            "limit": 100,
        },
    )
    for t in testers.get("data", []):
        a = t["attributes"]
        print(f"  {a.get('email'):40s} "
              f"{a.get('firstName') or ''} {a.get('lastName') or ''}  "
              f"state={a.get('inviteType')}")

    print()
    print("=" * 60)
    print("BUILD BETA DETAIL (review state)")
    print("=" * 60)
    r = get(f"/builds/{build_id}/buildBetaDetail", token)
    a = r.get("data", {}).get("attributes", {})
    print(f"  internalBuildState = {a.get('internalBuildState')}")
    print(f"  externalBuildState = {a.get('externalBuildState')}")
    print(f"  autoNotifyEnabled  = {a.get('autoNotifyEnabled')}")

if __name__ == "__main__":
    main()
