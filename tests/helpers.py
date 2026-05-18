from __future__ import annotations

import os
import shlex
import shutil
import subprocess  # nosec B404
import tempfile
import time
import uuid
from collections.abc import Iterator
from contextlib import contextmanager
from pathlib import Path

from tests.conftest import REPO_ROOT


def run_command(
    command: list[str],
    *,
    cwd: Path | None = None,
    check: bool = True,
    capture_output: bool = True,
) -> subprocess.CompletedProcess[str]:
    return subprocess.run(  # nosec B603
        command,
        cwd=cwd or REPO_ROOT,
        check=check,
        text=True,
        capture_output=capture_output,
    )


def docker_available() -> bool:
    return (
        shutil.which("docker") is not None
        and run_command(["docker", "info"], check=False).returncode == 0
    )


def docker_image_exists(image_tag: str) -> bool:
    return (
        run_command(["docker", "image", "inspect", image_tag], check=False).returncode
        == 0
    )


def ensure_image(
    image_tag: str, *, context: str = ".", dockerfile: str = "Dockerfile"
) -> None:
    env_key = "NANOCLAW_AIO_PYTEST_USE_PREBUILT_IMAGE"
    if os.environ.get(env_key) == "true":
        if not docker_image_exists(image_tag):
            raise AssertionError(f"{env_key}=true but {image_tag} is not loaded")
        return
    run_command(
        [
            "docker",
            "build",
            "--platform",
            "linux/amd64",
            "-t",
            image_tag,
            "-f",
            dockerfile,
            context,
        ]
    )


@contextmanager
def temp_dir(prefix: str) -> Iterator[Path]:
    path = Path(tempfile.mkdtemp(prefix=f"{prefix}-"))
    try:
        yield path
    finally:
        shutil.rmtree(path, ignore_errors=True)


class DockerRuntime:
    def __init__(self, image_tag: str) -> None:
        self.image_tag = image_tag

    def build(self) -> None:
        ensure_image(self.image_tag)

    def logs(self, name: str) -> str:
        result = run_command(["docker", "logs", name], check=False)
        return result.stdout + result.stderr

    def inspect_state(self, name: str, field: str) -> str:
        result = run_command(
            ["docker", "inspect", "-f", f"{{{{.{field}}}}}", name], check=False
        )
        return result.stdout.strip() if result.returncode == 0 else ""

    def remove(self, name: str) -> None:
        run_command(["docker", "rm", "-f", name], check=False)

    @contextmanager
    def container(
        self,
        *,
        appdata: Path,
        env_overrides: dict[str, str] | None = None,
        mount_docker_socket: bool = False,
    ) -> Iterator["ContainerHandle"]:
        name = f"nanoclaw-aio-pytest-{uuid.uuid4().hex[:10]}"
        command = [
            "docker",
            "run",
            "-d",
            "--platform",
            "linux/amd64",
            "--name",
            name,
            "-v",
            f"{appdata}:/appdata",
            "-e",
            f"NANOCLAW_HOST_APPDATA_DIR={appdata}",
        ]
        if mount_docker_socket:
            command.extend(["-v", "/var/run/docker.sock:/var/run/docker.sock"])
        if env_overrides:
            for key, value in env_overrides.items():
                command.extend(["-e", f"{key}={value}"])
        command.append(self.image_tag)
        run_command(command)
        handle = ContainerHandle(runtime=self, name=name, appdata=appdata)
        try:
            yield handle
        finally:
            self.remove(name)


class ContainerHandle:
    def __init__(self, *, runtime: DockerRuntime, name: str, appdata: Path) -> None:
        self.runtime = runtime
        self.name = name
        self.appdata = appdata

    def logs(self) -> str:
        return self.runtime.logs(self.name)

    def exec(
        self, command: str, *, check: bool = True
    ) -> subprocess.CompletedProcess[str]:
        return run_command(
            ["docker", "exec", self.name, "bash", "-lc", command], check=check
        )

    def restart(self) -> None:
        run_command(["docker", "restart", self.name])

    def is_running(self) -> bool:
        return self.runtime.inspect_state(self.name, "State.Status") == "running"

    def wait_for_log(self, needle: str, *, timeout: int = 60) -> None:
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            if needle in self.logs():
                return
            time.sleep(1)
        raise AssertionError(
            f"Timed out waiting for log line {needle!r}\n{self.logs()}"
        )

    def path_exists(self, path: str) -> bool:
        return self.exec(f"test -e {shlex.quote(path)}", check=False).returncode == 0

    def read_file(self, path: str) -> str:
        return self.exec(f"cat {shlex.quote(path)}").stdout
