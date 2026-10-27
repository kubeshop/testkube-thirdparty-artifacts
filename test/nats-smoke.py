#!/usr/bin/env python3
"""Check a locally built image: python3 test/nats-smoke.py IMAGE."""

import base64
import json
from pathlib import Path
import socket
import subprocess
import sys
import time
import urllib.error
import urllib.request
import uuid


def docker(*args):
    return subprocess.check_output(["docker", *args], text=True, timeout=60).strip()


def main(image):
    name = "nats-smoke-" + uuid.uuid4().hex[:12]
    dockerfile = Path(__file__).resolve().parents[1] / "nats/nats-release.dockerfile"
    version = next(line.split(":")[1].split("-")[0]
                   for line in dockerfile.read_text().splitlines() if line.startswith("FROM nats:"))
    docker("volume", "create", name)
    try:
        # Leading flags exercise the upstream shell entrypoint used by Helm.
        docker("run", "-d", "--name", name, "--read-only", "--tmpfs", "/tmp",
               "-v", f"{name}:/data", "-p", "127.0.0.1::4222", "-p", "127.0.0.1::8222",
               image, "--jetstream", "--store_dir", "/data", "--auth", "smoke-token",
               "--http_port", "8222", "--pid", "/tmp/nats.pid")
        port = int(docker("port", name, "4222/tcp").rsplit(":", 1)[1])
        monitor = int(docker("port", name, "8222/tcp").rsplit(":", 1)[1])

        def ready():
            for _ in range(60):
                assert docker("inspect", "--format", "{{.State.Running}}", name) == "true", "NATS exited"
                try:
                    with urllib.request.urlopen(f"http://127.0.0.1:{monitor}/healthz", timeout=5) as response:
                        assert response.status == 200
                        return
                except (OSError, urllib.error.URLError):
                    time.sleep(1)
            raise AssertionError("NATS health probe did not become ready")

        def exchange(subject, payload=b"", reply=True):
            with socket.create_connection(("127.0.0.1", port), timeout=10) as connection:
                with connection.makefile("rwb", buffering=0) as stream:
                    info = stream.readline()
                    assert info.startswith(b"INFO ") and json.loads(info[5:])["version"] == version
                    inbox = "_INBOX.smoke" if reply else subject
                    destination = subject + " " + inbox if reply else subject
                    stream.write(b'CONNECT {"auth_token":"smoke-token","verbose":false}\r\n')
                    stream.write(f"SUB {inbox} 1\r\nUNSUB 1 1\r\nPUB {destination} {len(payload)}\r\n".encode()
                                 + payload + b"\r\nPING\r\n")
                    for _ in range(20):
                        line = stream.readline()
                        assert line and not line.startswith(b"-ERR"), line
                        if line == b"PING\r\n":
                            stream.write(b"PONG\r\n")
                        elif line.startswith(b"MSG "):
                            length = int(line.split()[-1])
                            data = stream.read(length)
                            assert len(data) == length and stream.read(2) == b"\r\n"
                            return data
                    raise AssertionError("NATS did not deliver a response")

        def api(subject, payload):
            result = json.loads(exchange(subject, json.dumps(payload).encode()))
            assert "error" not in result, result
            return result

        ready()
        assert exchange("smoke.basic", b"pubsub", reply=False) == b"pubsub"
        with socket.create_connection(("127.0.0.1", port), timeout=10) as connection:
            with connection.makefile("rwb", buffering=0) as stream:
                assert stream.readline().startswith(b"INFO ")
                stream.write(b'CONNECT {"auth_token":"wrong"}\r\nPING\r\n')
                assert b"Authorization Violation" in stream.readline(), "Invalid token was not rejected"
        api("$JS.API.STREAM.CREATE.SMOKE", {"name": "SMOKE", "subjects": ["persist.smoke"],
                                           "storage": "file", "num_replicas": 1})
        acknowledgment = json.loads(exchange("persist.smoke", b"stored-message"))
        assert acknowledgment["stream"] == "SMOKE" and acknowledgment["seq"] == 1
        docker("restart", name)
        port = int(docker("port", name, "4222/tcp").rsplit(":", 1)[1])
        monitor = int(docker("port", name, "8222/tcp").rsplit(":", 1)[1])
        ready()
        message = api("$JS.API.STREAM.MSG.GET.SMOKE", {"seq": 1})["message"]
        assert base64.b64decode(message["data"]) == b"stored-message"
        # Helm's lifecycle hook invokes the server binary to signal the running PID.
        docker("exec", name, "nats-server", "--signal", "quit=/tmp/nats.pid")
        assert docker("wait", name) == "0"
        print(f"PASS {image}: read-only startup, flag entrypoint, health, pub/sub, invalid-token "
              "rejection, JetStream file persistence after restart, and graceful shutdown")
    except BaseException:
        subprocess.run(["docker", "logs", name], check=False)
        raise
    finally:
        subprocess.run(["docker", "rm", "-f", name], check=False, stdout=subprocess.DEVNULL)
        subprocess.run(["docker", "volume", "rm", name], check=False, stdout=subprocess.DEVNULL)


if __name__ == "__main__":
    main(sys.argv[1])
