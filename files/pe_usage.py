"""PE compatibility defaults for usage detail fields unreported by an upstream.

Zero defaults prevent PE's null dereference; they are not measured cache or
reasoning counts. Actual aggregate counts and supplied detail values are retained.
"""
from copy import deepcopy


def normalize_usage(usage):
    if usage is None:
        return None
    if not isinstance(usage, dict):
        raise ValueError('usage object required')
    result = deepcopy(usage)
    defaults = {
        'prompt_tokens_details': ['cached_tokens', 'audio_tokens'],
        'completion_tokens_details': ['reasoning_tokens', 'audio_tokens',
                                      'accepted_prediction_tokens', 'rejected_prediction_tokens'],
    }
    for name, fields in defaults.items():
        detail = result.get(name)
        if detail is None:
            detail = {}
        if not isinstance(detail, dict):
            raise ValueError('usage details object required')
        for field in fields:
            if detail.get(field) is None:
                detail[field] = 0
        result[name] = detail
    return result
