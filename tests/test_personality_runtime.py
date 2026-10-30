"""Run inside the pinned LiteLLM image with its real callback base classes."""
import copy
import sys
import unittest
from pathlib import Path
from unittest.mock import patch
from litellm.integrations.custom_logger import CustomLogger
from litellm.types.utils import ModelResponse, Usage
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'files'))
with patch.object(Path, 'read_text', return_value='Talk like a pirate'):
    from personality_callback import proxy_handler
from pe_compat import proxy_handler as usage_handler


class PersonalityRuntimeTests(unittest.IsolatedAsyncioTestCase):
    async def test_real_hook_preserves_request_and_supplements_system(self):
        self.assertIsInstance(proxy_handler, CustomLogger)
        data = {'model': 'o4-mini', 'messages': [{'role': 'system', 'content': 'PE instructions'},
                {'role': 'user', 'content': 'Hello'}], 'tools': [{'type': 'function'}]}
        before = copy.deepcopy(data)
        result = await proxy_handler.async_pre_call_hook(None, None, data, 'completion')
        self.assertIn('Talk like a pirate', result['messages'][0]['content'])
        self.assertTrue(result['messages'][0]['content'].startswith('PE instructions'))
        self.assertEqual(result['tools'], data['tools'])
        self.assertEqual(data, before)

    async def test_real_proxy_acompletion_type_applies_style(self):
        data = {'messages': [{'role': 'system', 'content': 'PE instructions'}]}
        result = await proxy_handler.async_pre_call_hook(None, None, data, 'acompletion')
        self.assertIn('Talk like a pirate', result['messages'][0]['content'])

    async def test_embeddings_and_missing_messages_are_unchanged(self):
        data = {'input': 'embed me'}
        self.assertIs(await proxy_handler.async_pre_call_hook(None, None, data, 'embedding'), data)
        self.assertIs(await proxy_handler.async_pre_call_hook(None, None, data, 'completion'), data)

    async def test_usage_callback_still_normalizes_after_personality(self):
        data = {'messages': [{'role': 'user', 'content': 'Hello'}]}
        result = await proxy_handler.async_pre_call_hook(None, None, data, 'completion')
        response = ModelResponse(usage=Usage(prompt_tokens=3, completion_tokens=4, total_tokens=7))
        response = await usage_handler.async_post_call_success_hook(result, None, response)
        self.assertEqual(response.usage.prompt_tokens_details.cached_tokens, 0)
        self.assertEqual(response.usage.total_tokens, 7)

if __name__ == '__main__':
    unittest.main()
