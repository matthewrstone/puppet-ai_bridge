# Phase 2 — LiteLLM bridge

## Goal
A single config that exposes `o4-mini` and routes it to the chosen backend.

## Backends
| `backend` | LiteLLM model string | Needs |
|-----------|----------------------|-------|
| anthropic | `anthropic/<model>` | `ANTHROPIC_API_KEY` |
| openai | `openai/<model>` | `OPENAI_API_KEY` |
| ollama | `ollama_chat/<model>` + `api_base` | reachable Ollama |
| openai_compatible | `openai/<model>` + `api_base` (+ optional key) | vLLM / LM Studio / PAG |

## Notes
- `drop_params: true` so reasoning-model params PE may send (`reasoning_effort`,
  `max_completion_tokens`) don't 400 on providers that don't accept them.
- `master_key` is mandatory; it's what goes into the PE "API key" field.
- Request logging off by default; `LITELLM_LOG=DEBUG` toggle for troubleshooting.
- Health endpoints `/health/liveliness`, `/health/readiness` for systemd/monitoring.

## Tasks
- [x] `litellm/config.yaml` reference config (all four backends, commented)
- [x] `litellm/docker-compose.yml` + `.env.example`
- [x] Config validated by `python -c yaml.safe_load`
