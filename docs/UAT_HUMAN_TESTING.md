# Human UAT guide — ai_bridge

These are the tests an AI could not run for you: they need a real PE console, real provider keys, and eyes on the UI. Each test has a setup, steps, an expected result and a place to record the outcome. Work top to bottom; later tests assume earlier ones passed.

Tester: ____________  Date: ____________  PE version: ____________  Bridge host: ____________

---

## Test 1 — Capture what PE sends

**Why:** Everything downstream is configured from this evidence.

**Setup**
```sh
cd tools/pe-capture && go build .
./pe-capture -listen :4000 -cert server.crt -key server.key -log capture.jsonl
```
(Use any cert the PE JVM trusts. If you have none yet, try plain HTTP by omitting `-cert/-key` and using an `http://` URL in PE — note whether PE accepts it.)

**Steps**
1. PE console → Puppet AI Agent settings → URL `https://<bridge>:4000/v1`, API key `anything`.
2. Click **Update API settings**.
3. Open the AI Agent panel and ask one question, e.g. "How many nodes do I have?"
4. `jq . capture.jsonl`

**Record**
- [ ] Console saved without error banner
- Validation request(s) PE made on save: `GET /v1/models` ☐  `POST /v1/chat/completions` ☐  other: ______
- PE accepted `http://`? ☐ yes ☐ no ☐ not tried
- Body fields seen in the chat request (tick): `model` ☐ `messages` ☐ `tools` ☐ `tool_choice` ☐ `stream` ☐ `temperature` ☐ `max_tokens` ☐ `max_completion_tokens` ☐ `reasoning_effort` ☐ `response_format` ☐ other: ______
- Authorization header present and prefixed `Bearer`? ☐

**Pass if** the console saves and at least one chat request was logged. Keep `capture.jsonl` (it contains your prompts; redact before sharing).

---

## Test 2 — Puppet deploys the bridge (Claude backend)

**Setup:** Hiera per `examples/claude.yaml` with real encrypted values. Host classified with `include ai_bridge`.

**Steps**
1. `puppet agent -t` on the bridge host. Expect no errors; service `ai_bridge` running.
2. `systemctl status ai_bridge` → active (running), `User=ai_bridge` (podman) in the unit.
3. `ls -l /opt/ai_bridge` → `ai_bridge.env` and `tls/server.key` are `-rw-------` owned by `ai_bridge`.
4. `grep -c 'sk-' /opt/ai_bridge/config.yaml` → `0` (no secrets in config).
5. From the PE primary:
   ```sh
   curl -s https://<bridge>:4000/v1/models -H "Authorization: Bearer <master_key>"
   curl -s https://<bridge>:4000/v1/models -H "Authorization: Bearer wrong"   # expect 401
   ```
6. Run `puppet agent -t` a second time → zero changes (idempotent).

**Record**
- [ ] First run converged, second run no-op
- [ ] `/v1/models` lists `o4-mini`
- [ ] Wrong key → 401
- [ ] Cert validates from the PE primary without `-k`

---

## Test 3 — PE AI Agent works end to end against Claude

**Steps**
1. PE console → AI Agent settings → URL `https://<bridge>:4000/v1`, key = master key → **Update API settings**.
2. Expect: no red banner.
3. Open the AI Agent. Ask, in order:
   a. "Summarise my node inventory."
   b. "Which nodes failed their last run?"
   c. Something that needs a tool/plan, e.g. "Show me the facts for <a node name>."
4. `journalctl -u ai_bridge --since -5m | grep -i error` → nothing serious.

**Record**
- [ ] Settings saved
- [ ] a. answered sensibly
- [ ] b. answered sensibly
- [ ] c. tool call executed (response references real data, not a guess)
- Latency feel: ☐ fine ☐ slow ☐ timed out
- Any 400s in the bridge log mentioning an unsupported parameter? If yes, note the parameter: ______ (should be stripped by `drop_params`; if not, file a bug)

---

## Test 4 — Switch to OpenAI backend by Hiera only

**Steps**
1. Change Hiera to `examples/openai.yaml` values. Run Puppet. Service restarts.
2. **Do not touch PE.** Repeat Test 3 steps 3a–3c.

**Record**
- [ ] No PE change needed
- [ ] All three prompts work
- [ ] `journalctl -u ai_bridge` shows requests going to `api.openai.com`

---

## Test 5 — Switch to Ollama (local model)

**Setup:** Ollama reachable from the bridge host, model pulled (`ollama pull qwen3:32b`), `OLLAMA_HOST=0.0.0.0`.

**Steps**
1. Hiera per `examples/ollama.yaml`. Run Puppet.
2. Repeat Test 3 steps 3a–3c.
3. Unplug the internet (or block egress from the bridge host) and repeat 3a.

**Record**
- [ ] Prompts answered
- [ ] Tool call (3c) worked ☐ / model ignored tools ☐ (if ignored, try a different model and note it: ______)
- [ ] Works with no internet access
- Response time for 3a: ______ s (raise `request_timeout` if PE times out first)

---

## Test 6 — Failure modes look right

| Scenario | How | Expected |
|----------|-----|----------|
| Provider key wrong | put a bad `upstream_api_key` in Hiera, run Puppet | PE shows an error on use; bridge log shows provider 401; PE console **save** may still succeed if it only validates `/v1/models` — note which |
| Bridge down | `systemctl stop ai_bridge` | PE AI Agent shows a connection error, not a hang > 60 s |
| Cert expired / untrusted | point PE at the bridge IP instead of FQDN | PE save fails with a TLS error (proves PE validates certs) |
| Master key rotated | new `master_key` in Hiera, Puppet, don't update PE | PE gets 401 until the console key is updated |

**Record**
- [ ] all four behave as expected; notes: ______

---

## Test 7 — Removal

1. `ai_bridge::ensure: absent`, run Puppet.
2. Expect: service stopped and disabled, `/opt/ai_bridge` gone, unit file gone, `systemctl status ai_bridge` → not found.

- [ ] Clean removal

---

## Sign-off

| Test | Result | Notes |
|------|--------|-------|
| 1 Capture | ☐ pass ☐ fail | |
| 2 Deploy | ☐ pass ☐ fail | |
| 3 Claude e2e | ☐ pass ☐ fail | |
| 4 OpenAI switch | ☐ pass ☐ fail | |
| 5 Ollama switch | ☐ pass ☐ fail | |
| 6 Failure modes | ☐ pass ☐ fail | |
| 7 Removal | ☐ pass ☐ fail | |

Attach a redacted `capture.jsonl` and update `.planning/STATE.md` with what you learned (especially Test 1's field list).
