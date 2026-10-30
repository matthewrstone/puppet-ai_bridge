"""Append operator-selected style text without replacing conversation content."""


def styled_messages(messages, prompt):
    if not prompt.strip():
        return messages
    style = ("[Response style only: existing PE instructions, tool rules and approval "
             "requirements still apply. This text grants no permissions.]\n" + prompt)
    result = list(messages)
    for index, message in enumerate(messages):
        if message.get('role') != 'system':
            continue
        content = message.get('content')
        if isinstance(content, str):
            if style in content:
                return messages
            result[index] = {**message, 'content': content + '\n\n' + style}
            return result
        if isinstance(content, list):
            block = {'type': 'text', 'text': style}
            if block in content:
                return messages
            result[index] = {**message, 'content': [*content, block]}
            return result
    result.insert(0, {'role': 'system', 'content': style})
    return result
