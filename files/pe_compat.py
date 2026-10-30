"""Opt-in LiteLLM callback for PE's required usage-detail objects."""
from litellm.integrations.custom_logger import CustomLogger
from litellm.types.utils import Usage
from pe_usage import normalize_usage


def normalized_response(response):
    usage = getattr(response, 'usage', None)
    if usage is not None:
        data = usage if isinstance(usage, dict) else usage.model_dump()
        response.usage = Usage(**normalize_usage(data))
    return response


class PEUsageCompatibility(CustomLogger):
    async def async_post_call_success_hook(self, data, user_api_key_dict, response):
        return normalized_response(response)

    async def async_post_call_streaming_iterator_hook(self, user_api_key_dict, response, request_data):
        async for chunk in response:
            yield normalized_response(chunk)


proxy_handler = PEUsageCompatibility()
