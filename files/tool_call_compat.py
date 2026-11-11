"""Let tool-using models actually call their tools when PE also asks for a JSON schema.

PE's PuppetDB agent sends `tools` and a strict `response_format: json_schema` in the same
request. Schema-constrained decoding (for example Ollama's `format`) leaves no room for a
tool call, so the model fills the schema directly and invents the answer. Dropping the schema
until a tool result exists lets the model call the tool; the schema returns afterwards.
"""


def _has_tool_result(messages):
    return isinstance(messages, list) and any(
        isinstance(message, dict) and message.get('role') == 'tool' for message in messages)


def prepare_request(data):
    fmt = data.get('response_format')
    if not (isinstance(fmt, dict) and fmt.get('type') == 'json_schema'):
        return data
    if not data.get('tools') or data.get('tool_choice') == 'none':
        return data
    if _has_tool_result(data.get('messages')):
        return data
    return {key: value for key, value in data.items() if key != 'response_format'}
