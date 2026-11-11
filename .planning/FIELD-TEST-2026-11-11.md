# Field test — 2026-11-11

Status: partial; Phase 5 remains open.

## Automated checks

- Go race tests passed, 80.1% statement coverage; go vet and gofmt checks passed.
- Python helper tests: 17 passed.
- Real LiteLLM callback tests: 12 passed in the CI-pinned image.
- Puppet specs: 32 passed; Bolt specs: 4 passed, run in separate processes as in CI.
- Puppet parser, puppet-lint, metadata-json-lint passed.
- Six reference YAML files parsed successfully.
- Combining Puppet and Bolt specs in one process produced one initial catalog compilation failure; separate CI-style runs passed.

## Deployment and probes

- SSH user: ubuntu. PE: pe-advanced-01.pg.souldo.cloud, version 2026.0.0.
- Bridge: ai-bridge-01.pg.souldo.cloud; ai_bridge systemd service and Docker container running.
- PE settings already point to https://ai-bridge-01.pg.souldo.cloud/v1. No settings changed.
- Deployed aliases o4-mini and gpt-5.4-mini map to ollama_chat/gemma4:12b at http://192.168.1.214:11434.
- PE host HTTPS probe validated the bridge certificate; unauthenticated model listing returned 401.
- Bridge loopback health returned 200; authenticated model listing returned 200 and both aliases.
- Initial bridge completion returned 200 after 87.3 seconds, empty content with a 32-token limit; usage detail fields present.
- Direct Ollama request initially timed out after 20 seconds. User reported Ollama was coming back online.
- After recovery, direct Ollama request with think=false returned OK in 1.9 seconds.
- Bridge retry with a 512-token limit returned 200 after 12.6 seconds, empty content, finish_reason=length. This does not establish successful answer generation.
- Bridge-local HTTPS probe failed because its hostname resolves locally to 127.0.1.1, while nginx listens on the LAN address; the PE-host HTTPS probe succeeded.

## PE end-to-end result

Submitted a read-only question asking the managed node count. Conversation ID:
344af96f-7288-4c56-8e19-2fd1f57cefe2.

The UI remained at Thinking. Infra Assistant logs recorded an OpenAIIoException caused by an InterruptedIOException timeout at 2026-11-11T10:35:52Z for this conversation. This attempt overlapped upstream recovery and is inconclusive for steady-state behavior.

## Next checks

1. Start a fresh PE conversation after upstream recovery and repeat the node-count question.
2. Verify an actual tool result and compare it with the PE inventory (17 active nodes observed during this session).
3. If replies remain empty or time out, inspect reasoning/token-limit handling and streaming behavior with the deployed model.
4. Provider switching, Puppet convergence/idempotence, failure injection, removal, and real capture logging remain untested in this session.

## Continuation: recovered-upstream tests

- A bridge request with reasoning_effort=none returned BRIDGE_OK in 0.9 seconds. A request with reasoning_effort=high and think=false returned THINK_OFF_OK in 4.06 seconds. These request-only probes isolated a way to obtain usable replies without exhausting the token budget.
- Fresh PE conversation 022e3003-57a0-402c-bcab-92ad8c8652b0 completed with a query-error answer. Despite the UI's successful-looking progress text, PE logs showed queryPuppetDB failed twice because its nested model request used gpt-5.4, which was absent from the bridge.
- Added gpt-5.4 by copying the deployed gpt-5.4-mini mapping; retained a backup at /opt/ai_bridge/config.yaml.before-field-test-20261111T104408Z. Updated README's PE 2026 Hiera example with this alias.
- Independently queried PuppetDB using the PE primary's existing client certificate: nodes[count()] {} returned [{"count":17}].
- Conversation 2420b435-d922-49d2-9f46-e82498afa25b passed the model-alias boundary but ended with a PE stream timeout at 10:48:03Z. HTTP 200 alone did not establish completed streaming.
- Set think=false on all three deployed Gemma aliases, retaining /opt/ai_bridge/config.yaml.before-think-off-20261111T105011Z. After restart, a request with high reasoning effort returned a complete CONFIG_OK reply in 7.89 seconds, confirming the deployed override worked for that probe.
- Conversation ae1aeb84-4911-43fc-991b-bccb7e98291f was interrupted with HTTP 502. This does not evaluate the tuned configuration's steady-state end-to-end behavior: the scheduled Puppet agent compiled a catalog from pe-advanced-01, reverted config.yaml at 10:53:22Z, and restarted ai_bridge at 10:53:26Z. The service became active again at 10:53:47Z, with only o4-mini and gpt-5.4-mini and no think setting.

## Durable fixes required before another full retest

1. Put the gpt-5.4 alias in the bridge node's authoritative Hiera data, retaining gpt-5.4-mini and o4-mini.
2. Add module support for an optional Ollama think setting and configure false for this Gemma deployment. The current EPP template has no parameter for this setting; direct config edits are reverted by Puppet.
3. Apply Puppet, wait for API readiness, confirm a subsequent Puppet run is a no-op, then repeat the PE inventory test against the independent count of 17.

No persistent live Puppet source changes were made. The scheduled agent restored its original model configuration. Phase 5 remains partial, not passed.

## Continuation 2: durable deploy and root cause of the wrong node count

Deployed durably (all via Puppet/Hiera, no hand edits to generated files):
- Installed souldo-ai_bridge 0.1.3 into production on pe-advanced-01 (backup:
  /root/ai_bridge-backups/20261111T152626Z). Added gpt-5.4 to extra_aliases and
  ai_bridge::ollama_think=false in the bridge node's eyaml; ENC values untouched.
- ai-bridge-01: run 1 applied config + restart (ready ~48s); run 2 was a no-op (exit 0).
  /v1/models lists o4-mini, gpt-5.4-mini, gpt-5.4; each alias returned content, finish=stop.

PE acceptance, "How many nodes are managed?":
- Conversations 0925ea4b-a4c8-4ad9-bb7f-7af06f600d75 and bb172c21-ca8c-44ea-9512-4fcdb08b9a81.
- Transport PASS: 5 bridge requests all 200, no errors, stream completed, input re-enabled,
  no OpenAIIoException/timeout in infra-assistant.log.
- Answer FAIL: both said "1 node". PuppetDB nodes[count()] = 17 (also 17 active);
  PE Status page shows 18 active nodes (1 not reporting).

Root cause (debug logging enabled temporarily, then reverted):
- queryPuppetDB spawns a nested gpt-5.4 call carrying tool runPqlQuery AND a strict
  response_format json_schema (PuppetDbAgentResponse). Gemma on Ollama never calls the tool
  under that combination and fills the schema directly, inventing the count. Only one nested
  POST occurred; the generated PQL was correct but never executed.
- Probe through the bridge, same request shape: tools+json_schema -> no tool_calls,
  invented text; tools only -> tool_calls=[runPqlQuery].
- Not caused by personality_prompt, think=false or the aliases.

Proposed fix (0.1.4): LiteLLM pre-call callback that, when a request has tools and a
json_schema response_format and no tool-role message yet, drops response_format for that turn
so the model can call the tool; keep the schema once tool results are present.

Debug reverted via Hiera (debug=false); converge applied, follow-up run idempotent.

## Continuation 3: PE acceptance PASS with tool_call_compat (0.1.4 dev build)

- Deployed the working-tree 0.1.4 build to pe-advanced-01 (backup:
  /root/ai_bridge-backups/20261111T191435Z-pre014) with ai_bridge::tool_call_compat=true in the
  bridge eyaml. ai-bridge-01 converged (callbacks: pe_compat, personality_callback,
  tool_call_compat_callback); second run was a no-op (exit 0).
- Bridge probe, same shape as PE's nested call: tools+json_schema now returns tool_calls
  [runPqlQuery]; after a tool result the schema is restored and the answer was valid JSON (17).
- PE conversation 9c580ce5-0237-4c7a-a0dd-5cdd798bd3c4, "How many nodes are managed?":
  final answer 18 using nodes[count()] {}. Independent PuppetDB (PE primary client cert) at
  the time of the check: all nodes 18, active 18, none expired/deactivated. MATCH.
  The earlier independent count of 17 (same query, hours earlier) was not explained: the 18th
  node (pkm-cluster-..., catalog_timestamp null) was already shown on the PE Status page then.
- Bridge trail: 4 requests, all 200 (main, nested tool call, nested after tool result, final).
  No new errors in infra-assistant.log. UI: thinking cleared, input re-enabled.
- Model stayed gemma4:12b; the Qwen/tool-tuned comparison on spaceghost was not needed to pass.
- Still open: provider switching, real capture logging, failure injection, removal, and the
  full PE 2025.x vs 2026.x model-name matrix. Phase 5 is therefore passed for the inventory
  tool path only, not complete.
