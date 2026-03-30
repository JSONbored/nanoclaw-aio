#!/usr/bin/env python3
from __future__ import annotations

import configparser
import json
import os
import pathlib
import re
import sys
import urllib.error
import urllib.request


ROOT = pathlib.Path(".")
UPSTREAM_FILE = ROOT / "upstream.toml"
DOCKERFILE = ROOT / "Dockerfile"


def fail(message: str) -> "NoReturn":
    print(message, file=sys.stderr)
    raise SystemExit(1)


def http_json(url: str, headers: dict[str, str] | None = None) -> object:
    request = urllib.request.Request(
        url,
        headers={
            "Accept": "application/vnd.github+json, application/json",
            "User-Agent": "jsonbored-nanoclaw-aio",
            **(headers or {}),
        },
    )
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            return json.load(response)
    except urllib.error.HTTPError as exc:
        fail(f"HTTP error while requesting {url}: {exc.code} {exc.reason}")
    except urllib.error.URLError as exc:
        fail(f"Network error while requesting {url}: {exc.reason}")


def github_headers() -> dict[str, str]:
    token = os.environ.get("GITHUB_TOKEN", "").strip()
    if token:
        return {"Authorization": f"Bearer {token}"}
    return {}


def parse_upstream_toml(path: pathlib.Path) -> dict[str, dict[str, object]]:
    parser = configparser.ConfigParser()
    parser.optionxform = str
    parser.read_string(path.read_text(encoding="utf-8"))

    result: dict[str, dict[str, object]] = {}
    for section in parser.sections():
      values: dict[str, object] = {}
      for key, raw_value in parser.items(section):
        value = raw_value.strip()
        lower = value.lower()
        if lower == "true":
          values[key] = True
        elif lower == "false":
          values[key] = False
        else:
          values[key] = value.strip('"')
      result[section] = values
    return result


def read_docker_arg(key: str) -> str:
    pattern = re.compile(rf"^\s*ARG\s+{re.escape(key)}=(.+?)\s*$")
    for line in DOCKERFILE.read_text(encoding="utf-8").splitlines():
        match = pattern.match(line)
        if match:
            return match.group(1)
    fail(f"Could not find ARG {key} in Dockerfile")


def write_docker_arg(key: str, new_value: str) -> None:
    pattern = re.compile(rf"^(\s*ARG\s+{re.escape(key)}=).+?(\s*)$")
    updated_lines: list[str] = []
    changed = False
    for line in DOCKERFILE.read_text(encoding="utf-8").splitlines():
        match = pattern.match(line)
        if match:
            updated_lines.append(f"{match.group(1)}{new_value}{match.group(2)}")
            changed = True
        else:
            updated_lines.append(line)
    if not changed:
        fail(f"Could not update ARG {key} in Dockerfile")
    DOCKERFILE.write_text("\n".join(updated_lines) + "\n", encoding="utf-8")


def latest_github_file_version(repo: str, ref: str, version_file: str, version_field: str, version_prefix: str) -> str:
    data = http_json(
        f"https://api.github.com/repos/{repo}/contents/{version_file}?ref={ref}",
        github_headers(),
    )
    if not isinstance(data, dict):
        fail(f"Unexpected GitHub contents response for {repo}/{version_file}")
    encoded = data.get("content")
    if not isinstance(encoded, str):
        fail(f"Missing file content for {repo}/{version_file}")
    content = encoded.replace("\n", "")
    raw = json.loads(__import__("base64").b64decode(content))
    value = raw.get(version_field)
    if not isinstance(value, str) or not value.strip():
        fail(f"Missing {version_field} in {version_file}")
    version = value.strip()
    if version_prefix and not version.startswith(version_prefix):
        version = f"{version_prefix}{version}"
    return version


def latest_github_head_commit(repo: str, ref: str) -> str:
    data = http_json(f"https://api.github.com/repos/{repo}/branches/{ref}", github_headers())
    if not isinstance(data, dict):
        fail(f"Unexpected GitHub branch response for {repo}:{ref}")
    commit = data.get("commit", {})
    if not isinstance(commit, dict):
        fail(f"Missing commit data for {repo}:{ref}")
    sha = commit.get("sha")
    if not isinstance(sha, str) or not sha.strip():
        fail(f"Missing branch head sha for {repo}:{ref}")
    return sha.strip()


def write_outputs(outputs: dict[str, str]) -> None:
    github_output = os.environ.get("GITHUB_OUTPUT")
    if github_output:
        with open(github_output, "a", encoding="utf-8") as handle:
            for key, value in outputs.items():
                handle.write(f"{key}={value}\n")
    else:
        for key, value in outputs.items():
            print(f"{key}={value}")


def main() -> None:
    if not UPSTREAM_FILE.exists():
        fail("Missing upstream.toml")

    config = parse_upstream_toml(UPSTREAM_FILE)
    upstream = config.get("upstream")
    notifications = config.get("notifications", {})
    if not isinstance(upstream, dict):
        fail("Invalid upstream.toml: missing [upstream]")

    if str(upstream.get("type", "")).strip() != "github-file-version":
        fail(f"Unsupported upstream type: {upstream.get('type')}")

    repo = str(upstream.get("repo", "")).strip()
    ref = str(upstream.get("ref", "main")).strip() or "main"
    version_file = str(upstream.get("version_file", "")).strip()
    version_field = str(upstream.get("version_field", "")).strip()
    version_prefix = str(upstream.get("version_prefix", "")).strip()
    version_key = str(upstream.get("version_key", "")).strip()
    commit_key = str(upstream.get("commit_key", "")).strip()

    current_version = read_docker_arg(version_key)
    current_commit = read_docker_arg(commit_key)

    latest_version = latest_github_file_version(
        repo,
        ref,
        version_file,
        version_field,
        version_prefix,
    )
    latest_commit = latest_github_head_commit(repo, ref)

    updates_available = latest_version != current_version

    if os.environ.get("WRITE_UPSTREAM_VERSION") == "true" and updates_available:
        write_docker_arg(version_key, latest_version)
        write_docker_arg(commit_key, latest_commit)

    release_notes = ""
    if isinstance(notifications, dict):
        release_notes = str(notifications.get("release_notes_url", "")).strip()
    if not release_notes:
        release_notes = f"https://github.com/{repo}"

    write_outputs(
        {
            "current_version": current_version,
            "current_commit": current_commit,
            "latest_version": latest_version,
            "latest_commit": latest_commit,
            "updates_available": "true" if updates_available else "false",
            "strategy": str(upstream.get("strategy", "pr")).strip() or "pr",
            "upstream_name": str(upstream.get("name", "")).strip(),
            "release_notes_url": release_notes,
        }
    )


if __name__ == "__main__":
    main()
