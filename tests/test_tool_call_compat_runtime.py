"""Run inside the pinned LiteLLM image with its real callback base class."""
import copy
import sys
import unittest
from pathlib import Path
from litellm.integrations.custom_logger import CustomLogger
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'files'))
from tool_call_compat_callback import proxy_handler

SCHEMA = {'type': 'json_schema', 'json_schema': {'name': 'R', 'strict': True, 'schema': {'type': 'object'}}}


class ToolCallCompatRuntimeTests(unittest.IsolatedAsyncioTestCase):
    async def test_real_hook_drops_schema_on_first_turn_only(self):
        self.assertIsInstance(proxy_handler, CustomLogger)
        data = {'model': 'gpt-5.4', 'messages': [{'role': 'user', 'content': 'count nodes'}],
                'tools': [{'type': 'function'}], 'response_format': SCHEMA}
        before = copy.deepcopy(data)
        for call_type in ('completion', 'acompletion'):
            result = await proxy_handler.async_pre_call_hook(None, None, data, call_type)
            self.assertNotIn('response_format', result)
            self.assertEqual(result['tools'], data['tools'])
        self.assertEqual(data, before)
        followup = {**data, 'messages': [*data['messages'], {'role': 'tool', 'tool_call_id': 'c', 'content': '[]'}]}
        result = await proxy_handler.async_pre_call_hook(None, None, followup, 'acompletion')
        self.assertEqual(result['response_format'], SCHEMA)

    async def test_other_call_types_are_untouched(self):
        data = {'input': 'x', 'tools': [{}], 'response_format': SCHEMA}
        result = await proxy_handler.async_pre_call_hook(None, None, data, 'embeddings')
        self.assertEqual(result, data)


if __name__ == '__main__':
    unittest.main()
