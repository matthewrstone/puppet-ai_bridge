import copy
import sys
import unittest
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'files'))
from tool_call_compat import prepare_request

SCHEMA = {'type': 'json_schema', 'json_schema': {'name': 'R', 'strict': True, 'schema': {'type': 'object'}}}
TOOLS = [{'type': 'function', 'function': {'name': 'runPqlQuery'}}]
FIRST = [{'role': 'system', 'content': 'Always run queries with runPqlQuery'},
         {'role': 'user', 'content': 'How many nodes are managed?'}]


def request(**extra):
    return {'model': 'gpt-5.4', 'messages': list(FIRST), 'tools': TOOLS, 'response_format': SCHEMA, **extra}


class ToolCallCompatTests(unittest.TestCase):
    def test_drops_json_schema_until_a_tool_has_run_and_changes_nothing_else(self):
        data = request(store=False)
        before = copy.deepcopy(data)
        result = prepare_request(data)
        self.assertNotIn('response_format', result)
        self.assertEqual({k: v for k, v in data.items() if k != 'response_format'}, result)
        self.assertEqual(data, before)

    def test_keeps_schema_once_a_tool_result_is_present(self):
        messages = [*FIRST, {'role': 'assistant', 'content': None, 'tool_calls': [{'id': 'c1'}]},
                    {'role': 'tool', 'tool_call_id': 'c1', 'content': '[{"count":17}]'}]
        data = request(messages=messages)
        self.assertIs(prepare_request(data), data)

    def test_keeps_schema_when_no_tools_are_offered(self):
        for tools in (None, []):
            data = request(tools=tools)
            self.assertIs(prepare_request(data), data)
        data = request()
        del data['tools']
        self.assertIs(prepare_request(data), data)

    def test_only_json_schema_is_affected(self):
        for fmt in ({'type': 'json_object'}, {'type': 'text'}, None):
            data = request(response_format=fmt)
            self.assertIs(prepare_request(data), data)

    def test_respects_tool_choice_none(self):
        data = request(tool_choice='none')
        self.assertIs(prepare_request(data), data)

    def test_tolerates_missing_or_odd_messages(self):
        data = request()
        del data['messages']
        self.assertNotIn('response_format', prepare_request(data))
        data = request(messages=['not-a-dict', {'role': 'user'}])
        self.assertNotIn('response_format', prepare_request(data))


if __name__ == '__main__':
    unittest.main()
