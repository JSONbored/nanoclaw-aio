from __future__ import annotations

from pathlib import Path

import pytest

from tests.helpers import DockerRuntime, docker_available, ensure_image, temp_dir

pytestmark = pytest.mark.integration

AIO_IMAGE = "nanoclaw-aio:pytest"
AGENT_IMAGE = "jsonbored/nanoclaw-agent:v2.1.17-agent.1"


@pytest.fixture(scope="session")
def runtime() -> DockerRuntime:
    if not docker_available():
        pytest.skip("Docker is unavailable; integration tests require Docker.")

    ensure_image(
        AGENT_IMAGE,
        context="components/nanoclaw-agent",
        dockerfile="components/nanoclaw-agent/Dockerfile",
    )
    runtime = DockerRuntime(AIO_IMAGE)
    runtime.build()
    return runtime


def test_missing_config_boots_to_healthy_waiting_state(runtime: DockerRuntime) -> None:
    with temp_dir("nanoclaw-aio-appdata") as appdata:
        with runtime.container(appdata=appdata) as container:
            container.wait_for_log("Waiting for configuration. Set TELEGRAM_BOT_TOKEN")
            assert container.is_running()  # nosec B101
            assert container.path_exists("/appdata/.waiting-for-config")  # nosec B101
            assert container.path_exists("/appdata/.bootstrap-complete")  # nosec B101


def test_smoke_mode_initializes_appdata_and_survives_restart(
    runtime: DockerRuntime,
) -> None:
    with temp_dir("nanoclaw-aio-appdata") as appdata:
        with runtime.container(
            appdata=appdata,
            env_overrides={"SMOKE_TEST_MODE": "true"},
        ) as container:
            container.wait_for_log("Smoke mode initialized /appdata")
            assert container.path_exists("/appdata/.smoke-ready")  # nosec B101
            assert container.path_exists("/appdata/runtime/data/env/env")  # nosec B101
            assert container.path_exists(
                "/appdata/runtime/groups/global/CLAUDE.md"
            )  # nosec B101
            assert container.path_exists(
                "/appdata/runtime/container/agent-runner/src/index.ts"
            )  # nosec B101

            env_file = container.read_file("/appdata/runtime/data/env/env")
            assert f"CONTAINER_IMAGE={AGENT_IMAGE}" in env_file  # nosec B101
            assert f"NANOCLAW_HOST_APPDATA_DIR={appdata}" in env_file  # nosec B101

            container.restart()
            container.wait_for_log("Smoke mode initialized /appdata")
            assert container.path_exists(
                "/appdata/runtime/groups/main/CLAUDE.md"
            )  # nosec B101


def test_missing_docker_socket_is_clear_when_credentials_are_present(
    runtime: DockerRuntime,
) -> None:
    with temp_dir("nanoclaw-aio-appdata") as appdata:
        with runtime.container(
            appdata=appdata,
            env_overrides={
                "TELEGRAM_BOT_TOKEN": "test-token",  # nosec B105
                "ANTHROPIC_API_KEY": "test-key",
            },
        ) as container:
            container.wait_for_log("Docker socket is required")
            assert container.is_running()  # nosec B101
            assert container.path_exists(
                "/appdata/.docker-socket-missing"
            )  # nosec B101


def test_smoke_mode_can_see_configured_agent_image(runtime: DockerRuntime) -> None:
    docker_sock = Path("/var/run/docker.sock")
    if not docker_sock.exists():
        pytest.skip("Docker socket path is unavailable on this host.")

    with temp_dir("nanoclaw-aio-appdata") as appdata:
        with runtime.container(
            appdata=appdata,
            mount_docker_socket=True,
            env_overrides={
                "SMOKE_TEST_MODE": "true",
                "CONTAINER_IMAGE": AGENT_IMAGE,
            },
        ) as container:
            container.wait_for_log("Smoke mode initialized /appdata")
            result = container.exec('docker image inspect "$CONTAINER_IMAGE"')
            assert AGENT_IMAGE in result.stdout  # nosec B101
