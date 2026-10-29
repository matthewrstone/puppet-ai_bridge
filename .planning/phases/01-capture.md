# Phase 1 — Capture

## Goal
Learn exactly what the PE console and AI Agent send to the "OpenAI" endpoint, so the
bridge can be configured from evidence rather than guesses.

## Plan
- Go HTTP server, single static binary, no deps.
- Logs every request (method, path, headers with `Authorization` redacted, body) as one
  JSON line in `capture.jsonl`.
- Answers `GET /v1/models` with a list containing `o4-mini` (and any `-models` extras).
- Answers `POST /v1/chat/completions` with a syntactically valid completion so the console's
  validation passes; honours `stream: true` with SSE chunks.
- Optional `-upstream` flag: forward the request (after logging) to a real OpenAI-compatible
  server and relay the response. Lets the capture box act as a transparent tap.
- Optional `-rewrite-model` flag: rewrite the `model` field before forwarding. Turns the
  capture tool into a minimal zero-dependency bridge for the OpenAI→OpenAI case.
- TLS via `-cert`/`-key`.

## Tasks
- [x] Tests: models list, canned completion, stream, log line shape, redaction, rewrite, forward
- [x] Implementation
- [x] Dockerfile (scratch image)
- [ ] Run against real PE (Matthew)

## Acceptance
- `go test ./...` green.
- `curl -k https://host:4000/v1/models` lists `o4-mini`.
- PE console saves settings against it with no error banner.
