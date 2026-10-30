"""Execute inside the pinned LiteLLM image against its real response classes."""
import sys
from pathlib import Path
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "files"))
from litellm.types.utils import ModelResponse, ModelResponseStream, Usage
from pe_compat import proxy_handler


class CallbackRuntimeTests(unittest.IsolatedAsyncioTestCase):
    async def test_real_usage_preserves_counts_and_message(self):
        response = ModelResponse(usage=Usage(prompt_tokens=14, completion_tokens=8, total_tokens=22,
            prompt_tokens_details={'cached_tokens': 6}, completion_tokens_details={'reasoning_tokens':3}),
            choices=[{'index':0,'message':{'role':'assistant','content':'unchanged'},'finish_reason':'stop'}])
        result = await proxy_handler.async_post_call_success_hook({}, None, response)
        data = result.model_dump()
        self.assertEqual(data['usage']['prompt_tokens'],14)
        self.assertEqual(data['usage']['completion_tokens'],8)
        self.assertEqual(data['usage']['total_tokens'],22)
        self.assertEqual(data['usage']['prompt_tokens_details']['cached_tokens'],6)
        self.assertEqual(data['usage']['completion_tokens_details']['reasoning_tokens'],3)
        self.assertEqual(data['choices'][0]['message']['content'],'unchanged')

    async def test_real_usage_adds_pe_required_details(self):
        response=ModelResponse(usage=Usage(prompt_tokens=4,completion_tokens=3,total_tokens=7))
        result=await proxy_handler.async_post_call_success_hook({},None,response)
        data=result.model_dump()['usage']
        self.assertEqual(data['prompt_tokens_details']['cached_tokens'],0)
        self.assertEqual(data['completion_tokens_details']['reasoning_tokens'],0)
        self.assertEqual(data['total_tokens'],7)

    async def test_stream_keeps_payload_and_normalizes_final_usage(self):
        chunk=ModelResponseStream(usage=Usage(prompt_tokens=4,completion_tokens=3,total_tokens=7))
        async def chunks():
            yield b'unchanged-bytes'
            yield chunk
        result=[x async for x in proxy_handler.async_post_call_streaming_iterator_hook(None,chunks(),{})]
        self.assertEqual(result[0],b'unchanged-bytes')
        self.assertIs(result[1],chunk)
        self.assertEqual(result[1].model_dump()['usage']['prompt_tokens_details']['cached_tokens'],0)


if __name__=='__main__':unittest.main()
