from __future__ import annotations

from aio_fleet.app_testing import DockerRuntime as BaseDockerRuntime
from aio_fleet.app_testing import *  # noqa: F403
from aio_fleet.app_testing import configure_docker_exec, configure_repo_root
from aio_fleet.app_testing import ensure_image as _ensure_image

from tests.conftest import REPO_ROOT

configure_repo_root(REPO_ROOT)
configure_docker_exec(shell="bash")  # nosec B604


def ensure_image(
    image_tag: str,
    *,
    context: str = ".",
    dockerfile: str = "Dockerfile",
) -> None:
    _ensure_image(
        image_tag,
        context=context,
        dockerfile=dockerfile,
        prebuilt_env="NANOCLAW_AIO_PYTEST_USE_PREBUILT_IMAGE",
    )


class DockerRuntime(BaseDockerRuntime):
    def __init__(self, image_tag: str) -> None:
        super().__init__(
            image_tag,
            name_prefix="nanoclaw-aio-pytest",
            port_mappings=(),
            volume_mounts=(),
            exec_shell="bash",
            appdata_env_name="NANOCLAW_HOST_APPDATA_DIR",
        )

    def build(self) -> None:
        ensure_image(self.image_tag)
