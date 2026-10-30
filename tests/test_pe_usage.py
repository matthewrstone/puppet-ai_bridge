import copy
import sys
from pathlib import Path
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'files'))
from pe_usage import normalize_usage


class UsageCompatibilityTests(unittest.TestCase):
    def test_missing_details_get_zero_defaults_without_changing_totals(self):
        original = {'prompt_tokens': 14, 'completion_tokens': 8, 'total_tokens': 22}
        result = normalize_usage(original)
        self.assertEqual(result['prompt_tokens_details']['cached_tokens'], 0)
        self.assertEqual(result['completion_tokens_details']['reasoning_tokens'], 0)
        self.assertEqual(result['total_tokens'], 22)
        self.assertEqual(result['prompt_tokens'], 14)
        self.assertEqual(original, {'prompt_tokens': 14, 'completion_tokens': 8, 'total_tokens': 22})

    def test_existing_details_are_preserved_and_input_is_not_mutated(self):
        original = {'prompt_tokens_details': {'cached_tokens': 6, 'custom': 'keep'},
                    'completion_tokens_details': {'reasoning_tokens': 3}}
        before = copy.deepcopy(original)
        result = normalize_usage(original)
        self.assertEqual(result['prompt_tokens_details']['cached_tokens'], 6)
        self.assertEqual(result['completion_tokens_details']['reasoning_tokens'], 3)
        self.assertEqual(result['prompt_tokens_details']['custom'], 'keep')
        self.assertEqual(original, before)

    def test_null_detail_objects_and_fields_get_defaults(self):
        result = normalize_usage({'prompt_tokens_details': None,
                                  'completion_tokens_details': {'reasoning_tokens': None}})
        self.assertEqual(result['prompt_tokens_details']['cached_tokens'], 0)
        self.assertEqual(result['completion_tokens_details']['reasoning_tokens'], 0)

    def test_missing_usage_does_not_invent_token_measurements(self):
        self.assertIsNone(normalize_usage(None))

    def test_malformed_detail_shape_is_not_silently_replaced(self):
        with self.assertRaises(ValueError):
            normalize_usage({'prompt_tokens_details': 'invalid'})


if __name__ == '__main__': unittest.main()
