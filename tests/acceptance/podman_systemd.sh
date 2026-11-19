#!/usr/bin/env bash
# Acceptance test: deploy ai_bridge with rootless Podman under systemd and check it runs.
#
# Automates the deploy checks from docs/UAT_HUMAN_TESTING.md Test 2 that need no PE
# primary or real model: puppet apply converges, the unit runs rootless as the service
# user, secret file modes, no secrets in config.yaml, /v1/models auth, idempotence,
# restart and stop under systemd.
#
# DESTRUCTIVE: creates the ai_bridge user, /opt/ai_bridge and a systemd unit. Run it
# only on a disposable host (CI runner or throwaway VM), as root, with systemd and
# podman installed. It refuses to run unless CI=true or AI_BRIDGE_ACCEPTANCE=1.
#
# Environment:
#   PUPPET      puppet command (default: puppet). CI uses "bundle exec puppet".
#   MODULEPATH  module path holding ai_bridge (default: spec/fixtures/modules).
#   IMAGE       LiteLLM image (default: the digest-pinned image CI already reviews).
#   CONTROL=1   also run an informational control: the unit without the cgroupfs
#               flags. Its result is reported but never fails the test.
set -euo pipefail

if [ "${CI:-}" != "true" ] && [ "${AI_BRIDGE_ACCEPTANCE:-}" != "1" ]; then
  echo "Refusing to run: this test changes the host. Set AI_BRIDGE_ACCEPTANCE=1 on a disposable host." >&2
  exit 2
fi
[ "$(id -u)" = 0 ] || { echo "Run as root." >&2; exit 2; }

PUPPET=${PUPPET:-puppet}
MODULEPATH=${MODULEPATH:-spec/fixtures/modules}
IMAGE=${IMAGE:-ghcr.io/berriai/litellm@sha256:37e2dafb088a7723beb998590682957386dfc83ffea1848486f8e0e5cfac0b06}
DIR=/opt/ai_bridge
USER_NAME=ai_bridge
UNIT=/etc/systemd/system/ai_bridge.service
MASTER_KEY="sk-accept-$(od -An -N8 -tx1 /dev/urandom | tr -d ' \n')"
WORK=$(mktemp -d)
FLAGS='--cgroup-manager=cgroupfs --events-backend=file'
FAILURES=0

pass() { echo "PASS: $*"; }
fail() { echo "FAIL: $*" >&2; FAILURES=$((FAILURES + 1)); }
check() { local desc=$1; shift; if "$@"; then pass "$desc"; else fail "$desc"; fi; }

dump_logs() {
  echo "---- systemctl status ai_bridge ----"; systemctl status ai_bridge --no-pager || true
  echo "---- journalctl -u ai_bridge ----"; journalctl -u ai_bridge -n 200 --no-pager || true
}
trap 'rc=$?; [ $rc -eq 0 ] || dump_logs; rm -rf "$WORK"' EXIT

# Self-signed TLS material for localhost, so the TLS path is covered too.
openssl req -x509 -newkey rsa:2048 -nodes -days 1 -subj '/CN=localhost' \
  -addext 'subjectAltName=DNS:localhost,IP:127.0.0.1' \
  -keyout "$WORK/server.key" -out "$WORK/server.crt" 2>/dev/null

manifest() {
  cat > "$WORK/site.pp" <<EOF
class { 'ai_bridge':
  master_key        => Sensitive('${MASTER_KEY}'),
  backend           => 'ollama',
  upstream_model    => 'acceptance:latest',
  upstream_base_url => 'http://127.0.0.1:11434',
  container_runtime => 'podman',
  manage_package    => false,
  image             => '${IMAGE}',
  tls_cert          => file('${WORK}/server.crt'),
  tls_key           => Sensitive(file('${WORK}/server.key')),
  service_ensure    => '$1',
}
EOF
}

# puppet apply with --detailed-exitcodes: 0 = no changes, 2 = changes, 4/6 = failures.
apply() {
  local rc=0
  $PUPPET apply --modulepath "$MODULEPATH" --detailed-exitcodes "$WORK/site.pp" || rc=$?
  return $rc
}

# Clean environment like a system unit with User=: only HOME (from passwd) and PATH.
as_user() { sudo -u "$USER_NAME" env -i "HOME=$DIR" PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin sh -c "cd '$DIR' && $*"; }

wait_healthy() {
  for _ in $(seq 1 90); do
    if curl -fsS --cacert "$WORK/server.crt" https://localhost:4000/health/liveliness >/dev/null 2>&1; then
      return 0
    fi
    sleep 2
  done
  return 1
}

http_code() { curl -s -o /dev/null -w '%{http_code}' --cacert "$WORK/server.crt" "$@"; }

echo "== 1. First apply (service stopped) creates user, files and unit"
manifest stopped
rc=0; apply || rc=$?
check "first apply converges with changes (exit $rc)" test "$rc" = 2

echo "== 2. Pre-pull the image as $USER_NAME (avoids the unit's 300s start timeout)"
as_user "podman $FLAGS pull -q '$IMAGE'" >/dev/null

echo "== 3. Second apply starts the service"
manifest running
rc=0; apply || rc=$?
check "second apply converges (exit $rc)" test "$rc" = 2
check "service is active" systemctl is-active --quiet ai_bridge
check "bridge answers /health/liveliness over TLS" wait_healthy

echo "== 4. Unit and runtime checks"
check "unit runs as $USER_NAME" grep -qx "User=$USER_NAME" "$UNIT"
check "every podman Exec line carries the cgroupfs flags" \
  test "$(grep -c '/usr/bin/podman ' "$UNIT")" = "$(grep -c "/usr/bin/podman $FLAGS " "$UNIT")"
CONMON=$(pgrep -u "$USER_NAME" -x conmon | head -1 || true)
check "conmon runs as $USER_NAME (rootless)" test -n "$CONMON"
if [ -n "$CONMON" ]; then
  check "conmon is in ai_bridge.service's cgroup" grep -q 'ai_bridge.service' "/proc/$CONMON/cgroup"
fi
check "ai_bridge.env is 0600 owned by $USER_NAME" test "$(stat -c '%a %U' "$DIR/ai_bridge.env")" = "600 $USER_NAME"
check "tls/server.key is 0600 owned by $USER_NAME" test "$(stat -c '%a %U' "$DIR/tls/server.key")" = "600 $USER_NAME"
check "config.yaml holds no master key" bash -c "! grep -q '$MASTER_KEY' '$DIR/config.yaml'"

echo "== 5. API auth"
models=$(curl -fsS --cacert "$WORK/server.crt" -H "Authorization: Bearer $MASTER_KEY" https://localhost:4000/v1/models || true)
check "/v1/models lists o4-mini" grep -q '"o4-mini"' <<<"$models"
# LiteLLM without a database answers an unknown key with 400 "No connected db."
# rather than 401. Either way the key must be refused and no models returned.
wrong=$(curl -s -w '\n%{http_code}' --cacert "$WORK/server.crt" -H 'Authorization: Bearer wrong' https://localhost:4000/v1/models)
code=${wrong##*$'\n'}
check "wrong key is refused with 4xx (got $code)" test "${code:0:1}" = 4
body=${wrong%$'\n'*}
no_models() { ! grep -q 'o4-mini' <<<"$body"; }
check "wrong key gets no model list" no_models

echo "== 6. Idempotence"
rc=0; apply || rc=$?
check "third apply makes no changes (exit $rc)" test "$rc" = 0

echo "== 7. systemctl restart and stop"
systemctl restart ai_bridge
check "service is active after restart" systemctl is-active --quiet ai_bridge
check "bridge healthy after restart" wait_healthy
systemctl stop ai_bridge
sleep 2
check "stop leaves no conmon for $USER_NAME" bash -c "! pgrep -u '$USER_NAME' -x conmon >/dev/null"

if [ "${CONTROL:-}" = 1 ]; then
  echo "== Control (informational): same unit WITHOUT the cgroupfs flags"
  cp "$UNIT" "$WORK/unit.bak"
  sed -i "s|/usr/bin/podman $FLAGS |/usr/bin/podman |" "$UNIT"
  systemctl daemon-reload
  systemctl reset-failed ai_bridge 2>/dev/null || true
  if systemctl start ai_bridge && wait_healthy; then
    echo "CONTROL: without the flags the bridge also started on this host. Warnings logged:"
  else
    echo "CONTROL: without the flags the bridge FAILED to start on this host. Log:"
  fi
  journalctl -u ai_bridge --since '-3min' --no-pager | grep -iE 'cgroup|systemd|bus|session|events|error|warn' | tail -20 || true
  systemctl stop ai_bridge || true
  cp "$WORK/unit.bak" "$UNIT"
  systemctl daemon-reload
fi

echo
if [ "$FAILURES" -gt 0 ]; then
  echo "$FAILURES check(s) failed."
  exit 1
fi
echo "All checks passed."
