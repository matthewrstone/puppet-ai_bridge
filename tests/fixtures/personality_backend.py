"""Disposable OpenAI-compatible stub: fail unless style and original text arrive."""
from http.server import BaseHTTPRequestHandler, HTTPServer
import json
from pathlib import Path


class Handler(BaseHTTPRequestHandler):
    def do_POST(self):
        data = json.loads(self.rfile.read(int(self.headers.get('Content-Length', 0))))
        systems = [m.get('content', '') for m in data.get('messages', []) if m.get('role') == 'system']
        verified = any(isinstance(s, str) and s.startswith('Preserve PE approval requirements.')
                       and 'Talk like a pirate' in s and 'style only' in s for s in systems)
        user_preserved = any(m == {'role': 'user', 'content': 'synthetic'} for m in data.get('messages', []))
        result = {'style_on_upstream_wire': verified, 'original_user_preserved': user_preserved}
        Path('/root/personality-wire-evidence.json').write_text(json.dumps(result))
        ok = verified and user_preserved
        body = {'id': 'synthetic-style-check', 'object': 'chat.completion', 'created': 0,
                'model': 'synthetic-test', 'choices': [{'index': 0, 'message': {
                    'role': 'assistant', 'content': 'STYLE_WIRE_OK' if ok else 'STYLE_WIRE_MISSING'},
                    'finish_reason': 'stop'}], 'usage': {'prompt_tokens': 3, 'completion_tokens': 4, 'total_tokens': 7}}
        self.send_response(200 if ok else 422)
        self.send_header('Content-Type', 'application/json')
        self.end_headers()
        self.wfile.write(json.dumps(body).encode())

    def log_message(self, *args):
        pass


if __name__ == '__main__':
    HTTPServer(('172.17.0.1', 11434), Handler).serve_forever()
