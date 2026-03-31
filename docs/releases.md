# Releases

`nanoclaw-aio` uses upstream-version-plus-AIO-revision releases such as `v1.2.42-aio.1`.

## Version format

- first wrapper release for upstream `v1.2.42`: `v1.2.42-aio.1`
- second wrapper-only release on the same upstream: `v1.2.42-aio.2`
- first wrapper release after upgrading upstream: `v1.2.43-aio.1`

## Published image tags

Every `main` build publishes:

- `latest`
- the exact pinned upstream version
- an explicit packaging line tag like `v1.2.42-aio-v1`
- `sha-<commit>`

## Release flow

1. Trigger **Release / NanoClaw-AIO** from `main` with `action=prepare`.
2. The workflow computes the next `upstream-aio.N` version and opens a release PR.
3. Review and merge that PR into `main`.
4. Trigger **Release / NanoClaw-AIO** from `main` again with `action=publish`.
5. The workflow reads the merged `CHANGELOG.md` entry, creates the Git tag, and publishes the GitHub Release.
