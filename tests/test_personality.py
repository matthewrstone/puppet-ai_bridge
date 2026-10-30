import copy
import sys
import unittest
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'files'))
from personality import styled_messages


class PersonalityTests(unittest.TestCase):
    def test_appends_style_to_existing_system_preserving_original_messages(self):
        messages = [{'role': 'system', 'content': 'PE rules: request approval first.'},
                    {'role': 'developer', 'content': 'Only authorized read-only tools.'},
                    {'role': 'user', 'content': 'Explain this node'},
                    {'role': 'assistant', 'content': None, 'tool_calls': [{'id': 'call-1'}]},
                    {'role': 'tool', 'tool_call_id': 'call-1', 'content': 'tool output'}]
        before = copy.deepcopy(messages)
        result = styled_messages(messages, 'Talk like a pirate')
        self.assertTrue(result[0]['content'].startswith(messages[0]['content']))
        self.assertIn('Talk like a pirate', result[0]['content'])
        self.assertIn('style only', result[0]['content'])
        self.assertEqual(result[1:], messages[1:])
        self.assertEqual(messages, before)

    def test_preserves_structured_system_content(self):
        messages = [{'role': 'system', 'content': [{'type': 'text', 'text': 'PE rules'}]}]
        result = styled_messages(messages, 'Brief answers')
        self.assertEqual(result[0]['content'][0], messages[0]['content'][0])
        self.assertIn('Brief answers', result[0]['content'][-1]['text'])
        self.assertEqual(len(messages[0]['content']), 1)

    def test_adds_system_message_when_missing_without_swapping_existing_messages(self):
        messages = [{'role': 'user', 'content': 'Hello'}]
        result = styled_messages(messages, 'Friendly tone')
        self.assertEqual(result[1:], messages)
        self.assertEqual(result[0]['role'], 'system')

    def test_empty_style_is_noop(self):
        messages = [{'role': 'system', 'content': 'PE rules'}]
        self.assertEqual(styled_messages(messages, '  '), messages)

    def test_repeated_application_without_original_system_is_idempotent(self):
        first = styled_messages([{'role': 'user', 'content': 'Hello'}], 'Pirate')
        self.assertEqual(styled_messages(first, 'Pirate'), first)

    def test_repeated_application_does_not_duplicate_style(self):
        first = styled_messages([{'role': 'system', 'content': 'PE rules'}], 'Pirate')
        self.assertEqual(styled_messages(first, 'Pirate'), first)

if __name__ == '__main__':
    unittest.main()
