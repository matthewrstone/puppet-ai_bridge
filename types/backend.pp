# @summary Which provider the bridge forwards `o4-mini` to.
#
# - anthropic         Claude via the Anthropic API (needs upstream_api_key)
# - openai            A current OpenAI model, pure rename (needs upstream_api_key)
# - ollama            A local Ollama server (needs upstream_base_url)
# - openai_compatible vLLM, LM Studio, llama.cpp, TGI, PAG… (needs upstream_base_url)
type Ai_bridge::Backend = Enum['anthropic', 'openai', 'ollama', 'openai_compatible']
