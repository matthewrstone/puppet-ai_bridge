"""Optional chat style callback; style is plain data from a read-only file."""
from pathlib import Path
from litellm.integrations.custom_logger import CustomLogger
from personality import styled_messages


class PersonalityStyle(CustomLogger):
    def __init__(self):
        super().__init__()
        self.prompt = Path(__file__).with_name('personality.txt').read_text(encoding='utf-8')

    async def async_pre_call_hook(self, user_api_key_dict, cache, data, call_type):
        if call_type not in {'completion', 'acompletion'} or not isinstance(data.get('messages'), list):
            return data
        return {**data, 'messages': styled_messages(data['messages'], self.prompt)}


proxy_handler = PersonalityStyle()
