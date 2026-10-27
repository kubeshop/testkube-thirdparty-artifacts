#!/usr/bin/env python3
"""Run against a locally built Dex image: python3 test/dex-smoke.py IMAGE."""

import base64
import html
import http.cookiejar
import json
from pathlib import Path
import re
import socket
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.parse
import urllib.request
import uuid


def docker(*args):
    return subprocess.check_output(["docker", *args], text=True).strip()


class StopRedirects(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


def main(image):
    dockerfile = Path(__file__).resolve().parents[1] / "dex/dex-release.dockerfile"
    versions = dict(line[4:].split("=", 1) for line in dockerfile.read_text().splitlines()
                    if line.startswith("ARG ") and "=" in line)
    name = "dex-smoke-" + uuid.uuid4().hex[:12]
    with socket.socket() as listener:
        listener.bind(("127.0.0.1", 0))
        port = listener.getsockname()[1]
    issuer = f"http://127.0.0.1:{port}/dex"
    callback = issuer + "/test-callback"
    opener = urllib.request.build_opener(
        urllib.request.HTTPCookieProcessor(http.cookiejar.CookieJar()), StopRedirects()
    )

    def request(url, fields=None):
        data = urllib.parse.urlencode(fields).encode() if fields is not None else None
        try:
            response = opener.open(url, data, timeout=10)
        except urllib.error.HTTPError as error:
            response = error
        with response:
            return response.status, response.headers, response.read()

    def ready():
        for _ in range(90):
            assert docker("inspect", "--format", "{{.State.Running}}", name) == "true", "Dex exited"
            try:
                status, _, body = request(issuer + "/.well-known/openid-configuration")
                if status == 200:
                    discovery = json.loads(body)
                    assert discovery["issuer"] == issuer
                    return discovery
            except (OSError, urllib.error.URLError):
                pass
            time.sleep(1)
        raise AssertionError("Dex discovery did not become ready")

    def token(fields):
        status, _, body = request(issuer + "/token", {
            "client_id": "smoke", "client_secret": "smoke-secret", **fields
        })
        assert status == 200, (status, body)
        result = json.loads(body)
        assert result["access_token"] and result["id_token"] and result["refresh_token"]
        return result

    with tempfile.TemporaryDirectory(prefix=name) as directory:
        config = Path(directory) / "config.yaml"
        # The bcrypt hash is Dex's public example password, "password".
        config.write_text('''issuer: {{ getenv "DEX_ISSUER" }}
storage:
  type: sqlite3
  config:
    file: /var/dex/smoke.db
web:
  http: 0.0.0.0:5556
logger:
  level: debug
  format: json
expiry:
  deviceRequests: "5m"
  signingKeys: "6h"
  idTokens: "24h"
  refreshTokens:
    disableRotation: false
    reuseInterval: "3s"
    validIfNotUsedFor: "2160h"
    absoluteLifetime: "3960h"
oauth2:
  responseTypes: ["code"]
  skipApprovalScreen: true
  alwaysShowLoginScreen: false
  passwordConnector: local
enablePasswordDB: true
staticPasswords:
- email: admin@example.com
  hash: "$2a$10$2b2cU8CPhOTaGrs1HRQuAueS7JTT5ZHsHSzYiFPm1leZck7Mc8T4W"
  username: admin
  userID: smoke-user
staticClients:
- id: smoke
  name: Smoke test
  secret: smoke-secret
  redirectURIs:
  - ''' + callback + "\n")
        config.chmod(0o644)
        docker("volume", "create", name)
        try:
            docker("run", "-d", "--name", name, "--read-only", "--tmpfs", "/tmp",
                   "-p", f"127.0.0.1:{port}:5556", "-e", "DEX_ISSUER=" + issuer,
                   "-v", f"{name}:/var/dex", "-v", f"{config}:/etc/dex/smoke.yaml:ro",
                   image, "dex", "serve", "/etc/dex/smoke.yaml")
            assert docker("exec", name, "id", "-u") == "1001"
            assert versions["DEX_VERSION"] in docker("exec", name, "dex", "version")
            assert versions["GOMPLATE_VERSION"].lstrip("v") in docker("exec", name, "gomplate", "--version")
            discovery = ready()
            status, _, body = request(discovery["jwks_uri"])
            assert status == 200 and json.loads(body)["keys"]

            auth = issuer + "/auth?" + urllib.parse.urlencode({
                "client_id": "smoke", "redirect_uri": callback,
                "response_type": "code", "scope": "openid email profile offline_access",
                "state": "smoke-state", "nonce": "smoke-nonce"
            })
            login = auth
            for _ in range(10):
                status, headers, body = request(login)
                if status == 200:
                    break
                assert status in (302, 303), status
                login = urllib.parse.urljoin(login, headers["Location"])
            form = re.search(r'<form[^>]*action="([^"]+)"', body.decode())
            assert status == 200 and form, "Password form not found"
            login = urllib.parse.urljoin(login, html.unescape(form[1]))
            status, _, body = request(login, {"login": "admin@example.com", "password": "wrong"})
            assert status in (200, 401) and b"Invalid" in body, (status, body)
            status, headers, _ = request(login, {"login": "admin@example.com", "password": "password"})
            for _ in range(10):
                assert status in (302, 303), status
                location = urllib.parse.urljoin(login, headers["Location"])
                if location.startswith(callback + "?"):
                    break
                status, headers, _ = request(location)
            else:
                raise AssertionError("Login did not redirect to the registered callback")
            query = urllib.parse.parse_qs(urllib.parse.urlsplit(location).query)
            assert query["state"] == ["smoke-state"]
            fields = {"grant_type": "authorization_code", "code": query["code"][0],
                      "redirect_uri": callback}
            tokens = token(fields)
            payload = tokens["id_token"].split(".")[1]
            claims = json.loads(base64.urlsafe_b64decode(payload + "=" * (-len(payload) % 4)))
            assert claims["iss"] == issuer and claims["aud"] == "smoke"
            assert claims["email"] == "admin@example.com" and claims["nonce"] == "smoke-nonce"
            status, _, _ = request(issuer + "/token", {
                "client_id": "smoke", "client_secret": "smoke-secret", **fields
            })
            assert status == 400, "Authorization code was accepted twice"
            tokens = token({"grant_type": "refresh_token", "refresh_token": tokens["refresh_token"]})
            docker("restart", name)
            ready()
            token({"grant_type": "refresh_token", "refresh_token": tokens["refresh_token"]})
            print(f"PASS {image}: nonroot/read-only startup, templating, SQLite, discovery/JWKS, "
                  "invalid password, code login/replay rejection, refresh and restart persistence")
        except BaseException:
            subprocess.run(["docker", "logs", name], check=False)
            raise
        finally:
            docker("rm", "-f", name)
            docker("volume", "rm", name)


if __name__ == "__main__":
    main(sys.argv[1])
