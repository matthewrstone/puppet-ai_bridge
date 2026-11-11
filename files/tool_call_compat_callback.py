"""Optional pre-call hook; see tool_call_compat.py for why and when it acts."""
from litellm.integrations.custom_logger import CustomLogger
from tool_call_compat import prepare_request


class ToolCallCompatibility(CustomLogger):
    async def async_pre_call_hook(self, user_api_key_dict, cache, data, call_type):
        if call_type not in {'completion', 'acompletion'} or not isinstance(data, dict):
            return data
        return prepare_request(data)


proxy_handler = ToolCallCompatibility()
