# Dex image

The image retains the upstream Alpine layout, UID/GID 1001, web assets,
entrypoint, and default configuration. Dex and gomplate are rebuilt with patched
Go dependencies. Alpine packages are upgraded, with minimum versions for known
security fixes. Builder packages are upgraded too because Dex statically links
musl for SQLite support.

Dex 2.46 rejects unknown configuration fields. Validate custom configuration
before upgrading, and test your identity provider's login, refresh, and logout
flows. The local smoke test uses a test account and SQLite; it does not replace
deployment-specific identity provider or storage tests.

Run from the repository root for **each** of `arm64` and `amd64`:

```sh
arch=arm64
docker buildx build --platform "linux/$arch" --load \
  -t "testkube-dex:check-$arch" -f dex/dex-release.dockerfile dex
python3 test/dex-smoke.py "testkube-dex:check-$arch"
grype "docker:testkube-dex:check-$arch" --fail-on high
```

The smoke test requires Docker and Python 3 with its standard library. It checks
nonroot startup with a read-only root, config templating using Testkube's base
settings, discovery/JWKS, invalid-password rejection, authorization-code login
and replay rejection, refresh, and SQLite persistence across restart.

Scan the final published architecture digests again before release. Do not
ignore findings or filter to fixable findings when checking the High/Critical
release requirement.
