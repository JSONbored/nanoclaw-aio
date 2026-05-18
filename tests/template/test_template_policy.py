from __future__ import annotations

import re
import shutil
import subprocess  # nosec B404
import xml.etree.ElementTree as ET  # nosec B405

from tests.conftest import REPO_ROOT


def _xml_root() -> ET.Element:
    return ET.parse(REPO_ROOT / "nanoclaw-aio.xml").getroot()  # nosec B314


def _configs() -> dict[str, ET.Element]:
    return {
        str(config.attrib["Target"]): config
        for config in _xml_root().findall("Config")
        if "Target" in config.attrib
    }


def _expected_v2_targets() -> set[str]:
    return {
        "/appdata",
        "/var/run/docker.sock",
        "TELEGRAM_BOT_TOKEN",
        "ANTHROPIC_API_KEY",
        "NANOCLAW_HOST_APPDATA_DIR",
        "ANTHROPIC_AUTH_TOKEN",
        "ANTHROPIC_BASE_URL",
        "CLAUDE_CODE_OAUTH_TOKEN",
        "ONECLI_URL",
        "ONECLI_API_KEY",
        "CONTAINER_IMAGE",
        "CONTAINER_IMAGE_BASE",
        "CONTAINER_TIMEOUT",
        "IDLE_TIMEOUT",
        "CONTAINER_MAX_OUTPUT_SIZE",
        "MAX_MESSAGES_PER_PROMPT",
        "MAX_CONCURRENT_CONTAINERS",
        "LOG_LEVEL",
        "ASSISTANT_NAME",
        "ASSISTANT_HAS_OWN_NUMBER",
        "TZ",
    }


def _aio_fleet_required_targets() -> set[str]:
    targets: set[str] = set()
    in_required_targets = False
    required_targets_indent = -1

    for line in _read(".aio-fleet.yml").splitlines():
        stripped = line.strip()
        indent = len(line) - len(line.lstrip())
        if stripped == "required_targets:":
            in_required_targets = True
            required_targets_indent = indent
            continue
        if in_required_targets and stripped and indent <= required_targets_indent:
            break
        if in_required_targets and stripped.startswith("- "):
            targets.add(stripped[2:].strip().strip('"\''))

    assert targets, ".aio-fleet.yml missing validation.required_targets"  # nosec B101
    return targets


def _read(path: str) -> str:
    return (REPO_ROOT / path).read_text()


def _arg_value(dockerfile: str, arg_name: str) -> str:
    pattern = re.compile(rf"^ARG {re.escape(arg_name)}=(.+)$", re.MULTILINE)
    match = pattern.search(_read(dockerfile))
    assert match is not None, f"{dockerfile} missing ARG {arg_name}"  # nosec B101
    return match.group(1).strip()


def test_xml_parses_and_uses_v2_public_identity() -> None:
    root = _xml_root()

    assert root.findtext("Name") == "nanoclaw-aio"  # nosec B101
    assert root.findtext("Repository") == "jsonbored/nanoclaw-aio:latest"  # nosec B101
    assert (
        root.findtext("Registry") == "https://hub.docker.com/r/jsonbored/nanoclaw-aio"
    )  # nosec B101
    assert root.findtext("Project") == "https://github.com/JSONbored/nanoclaw-aio"  # nosec B101
    assert root.findtext("TemplateURL") == (  # nosec B101
        "https://raw.githubusercontent.com/JSONbored/awesome-unraid/main/nanoclaw-aio.xml"
    )
    assert root.findtext("Icon") == (  # nosec B101
        "https://raw.githubusercontent.com/JSONbored/awesome-unraid/main/icons/nanoclaw.webp"
    )
    assert root.findtext("Beta") == "True"  # nosec B101


def test_xml_uses_current_ca_category_tokens() -> None:
    category = _xml_root().findtext("Category") or ""
    tokens = set(category.split())

    assert tokens == {  # nosec B101
        "AI",
        "Productivity",
        "Network:Messenger",
        "Tools:Utilities",
    }
    assert all(not token.endswith(":") for token in tokens)  # nosec B101


def test_xml_exposes_required_and_advanced_v2_settings() -> None:
    configs = _configs()
    required_targets = _expected_v2_targets()

    assert required_targets <= set(configs)  # nosec B101
    assert configs["CONTAINER_IMAGE"].attrib["Default"] == (  # nosec B101
        "jsonbored/nanoclaw-agent:v2.0.63-agent.1"
    )
    assert configs["CONTAINER_IMAGE_BASE"].attrib["Default"] == (  # nosec B101
        "jsonbored/nanoclaw-agent"
    )
    assert configs["TELEGRAM_BOT_TOKEN"].attrib["Display"] == "always"  # nosec B101
    assert configs["/var/run/docker.sock"].attrib["Mode"] == "rw"  # nosec B101


def test_app_fleet_required_targets_match_v2_xml_surface() -> None:
    configs = _configs()
    app_fleet_targets = _aio_fleet_required_targets()
    required_xml_targets = {
        target
        for target, config in configs.items()
        if config.attrib.get("Required") == "true"
    }

    assert _expected_v2_targets() <= app_fleet_targets  # nosec B101
    assert required_xml_targets <= app_fleet_targets  # nosec B101


def test_xml_overview_warns_about_beta_docker_socket_and_pairing() -> None:
    overview = _xml_root().findtext("Overview") or ""

    for phrase in [
        "Telegram-first",
        "marked beta",
        "Docker socket",
        "host-level Docker control",
        "jsonbored/nanoclaw-agent",
        "PAIR_TELEGRAM_CODE",
        "/appdata",
    ]:
        assert phrase in overview  # nosec B101


def test_dockerfiles_pin_upstream_and_component_versions() -> None:
    assert _arg_value("Dockerfile", "UPSTREAM_VERSION") == "v2.0.63"  # nosec B101
    assert _arg_value("Dockerfile", "UPSTREAM_COMMIT") == (  # nosec B101
        "975a2f0f5b0ea19bbf35fadfd394df35e5341d3a"
    )
    assert _arg_value("Dockerfile", "CHANNELS_COMMIT") == (  # nosec B101
        "8e91d37bc9c14b06580bda4b46c85f33cf755b15"
    )
    assert _arg_value("Dockerfile", "AIO_REVISION") == "1"  # nosec B101
    assert (  # nosec B101
        _arg_value("components/nanoclaw-agent/Dockerfile", "UPSTREAM_VERSION")
        == "v2.0.63"
    )
    assert (  # nosec B101
        _arg_value("components/nanoclaw-agent/Dockerfile", "AGENT_REVISION") == "1"
    )
    assert "CLAUDE_CODE_VERSION=2.1.128" in _read(
        "components/nanoclaw-agent/Dockerfile"
    )  # nosec B101
    assert "BUN_VERSION=1.3.12" in _read(
        "components/nanoclaw-agent/Dockerfile"
    )  # nosec B101
    assert "PNPM_VERSION=10.33.0" in _read(
        "components/nanoclaw-agent/Dockerfile"
    )  # nosec B101


def test_aio_defaults_point_to_paired_agent_image() -> None:
    dockerfile = _read("Dockerfile")

    assert (
        'CONTAINER_IMAGE="jsonbored/nanoclaw-agent:${UPSTREAM_VERSION}-agent.1"'
        in dockerfile
    )  # nosec B101
    assert 'CONTAINER_IMAGE_BASE="jsonbored/nanoclaw-agent"' in dockerfile  # nosec B101
    assert "patches/unraid-host-paths.patch" in dockerfile  # nosec B101


def test_unraid_overlay_quotes_dynamic_docker_build_inputs() -> None:
    patch = _read("patches/unraid-host-paths.patch")

    assert "aptPackages.map(shellQuote)" in patch  # nosec B101
    assert "npmPackages.map(shellQuote)" in patch  # nosec B101
    assert "shellQuote(`only-built-dependencies[]=${p}`)" in patch  # nosec B101
    assert "build -t ${shellQuote(imageTag)}" in patch  # nosec B101


def test_docs_and_templates_do_not_expose_local_paths_or_stale_upstream() -> None:
    checked_paths = [
        path
        for path in REPO_ROOT.rglob("*")
        if path.is_file()
        and ".git" not in path.parts
        and path.suffix.lower() in {".md", ".xml", ".toml", ".yml", ".yaml"}
    ]
    combined = "\n".join(path.read_text(errors="ignore") for path in checked_paths)

    assert "/Users/" not in combined  # nosec B101
    assert "file:///tmp" not in combined  # nosec B101
    assert "qwibitai" not in combined  # nosec B101


def test_no_standalone_agent_unraid_template_exists() -> None:
    assert not (REPO_ROOT / "nanoclaw-agent.xml").exists()  # nosec B101


def test_no_stale_upstream_submodule_gitlink() -> None:
    git = shutil.which("git")
    assert git is not None  # nosec B101

    result = subprocess.run(  # nosec B603
        [git, "ls-files", "--stage", "upstream"],
        cwd=REPO_ROOT,
        check=True,
        capture_output=True,
        text=True,
    )

    assert result.stdout.strip() == ""  # nosec B101
