#!/usr/bin/env python3
"""Resolve a published stable upstream tag; never select main or prereleases."""
import argparse
import json
import os
import re
import subprocess
import sys
import urllib.error
import urllib.request
from pathlib import Path

REPO = "anefzaoui/misterdownloadmanager"
API = f"https://api.github.com/repos/{REPO}"
STABLE = re.compile(r"^v?(\d+)\.(\d+)\.(\d+)$")


def stable_key(tag):
    m = STABLE.fullmatch(tag)
    return tuple(map(int, m.groups())) if m else None


def fetch_json(url):
    req = urllib.request.Request(url, headers={
        "Accept": "application/vnd.github+json",
        "User-Agent": "mdm-native-builder-b1r5",
        "X-GitHub-Api-Version": "2022-11-28",
        **({"Authorization": f"Bearer {os.environ['GITHUB_TOKEN']}"} if os.environ.get("GITHUB_TOKEN") else {}),
    })
    try:
        with urllib.request.urlopen(req, timeout=30) as response:
            return json.load(response)
    except urllib.error.HTTPError as error:
        # A 404 is normal ONLY for optional exact release lookup, never silently
        # ignored by the stable-release enumerator.
        raise RuntimeError(f"GitHub API {error.code} for {url}") from error


def choose_release(releases, requested="latest"):
    eligible = []
    for release in releases:
        if release.get("draft") or release.get("prerelease"):
            continue
        tag = release.get("tag_name", "")
        key = stable_key(tag)
        if key is not None:
            eligible.append((key, tag, release))
    if requested.lower() != "latest":
        wanted = stable_key(requested)
        if wanted is None:
            raise ValueError("Explicit versions must be stable X.Y.Z (or vX.Y.Z)")
        eligible = [item for item in eligible if item[0] == wanted]
    if not eligible:
        raise ValueError(f"No published stable release for {requested!r}")
    eligible.sort(key=lambda item: item[0], reverse=True)
    return eligible[0][2]


def query_releases(requested):
    found = []
    for page in range(1, 11):
        batch = fetch_json(f"{API}/releases?per_page=100&page={page}")
        if not isinstance(batch, list):
            raise RuntimeError("GitHub API returned non-array releases")
        found.extend(batch)
        if len(batch) < 100:
            break
    return choose_release(found, requested)


def resolve_tag_sha(tag):
    # GitHub's git tag ref must exist. Prefer the peeled commit of annotated tags.
    cmd = ["git", "ls-remote", "https://github.com/anefzaoui/misterdownloadmanager.git",
           f"refs/tags/{tag}", f"refs/tags/{tag}^{{}}"]
    result = subprocess.run(cmd, check=True, capture_output=True, text=True, encoding="utf-8")
    refs = {}
    for row in result.stdout.splitlines():
        sha, ref = row.split("\t", 1)
        refs[ref] = sha
    sha = refs.get(f"refs/tags/{tag}^{{}}", refs.get(f"refs/tags/{tag}"))
    if not sha or not re.fullmatch("[0-9a-f]{40}", sha):
        raise RuntimeError(f"Stable tag missing or invalid: {tag}")
    return sha


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--version", default="latest")
    parser.add_argument("--revision", default="b1r5")
    parser.add_argument("--out", default="build-identity.json")
    args = parser.parse_args()
    if not re.fullmatch(r"b\d+r\d+(?:[._-][a-zA-Z0-9]+)?", args.revision):
        raise ValueError("Revision must be like b1r5")
    release = query_releases(args.version)
    tag = release["tag_name"]
    sha = resolve_tag_sha(tag)
    version = ".".join(map(str, stable_key(tag)))
    publish_tag = f"portable-mdm-v{version}-g{sha[:10]}-{args.revision}"
    identity = {
        "upstream_repo": REPO, "upstream_tag": tag, "upstream_sha": sha,
        "version": version, "builder_revision": args.revision,
        "release_tag": publish_tag,
        "upstream_release_url": release.get("html_url", ""),
        "build_mode": "NATIVE", "compiler": "Rust stable (MSVC x64)",
        "package_revisions": {"native": args.revision},
    }
    Path(args.out).write_text(json.dumps(identity, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(identity, indent=2))
    if os.environ.get("GITHUB_OUTPUT"):
        with open(os.environ["GITHUB_OUTPUT"], "a", encoding="utf-8", newline="\n") as stream:
            for key in ("upstream_tag", "upstream_sha", "version", "release_tag"):
                stream.write(f"{key}={identity[key]}\n")


if __name__ == "__main__":
    try:
        main()
    except (RuntimeError, ValueError, subprocess.CalledProcessError) as exc:
        print(f"RESOLUTION FAILED: {exc}", file=sys.stderr)
        sys.exit(1)
