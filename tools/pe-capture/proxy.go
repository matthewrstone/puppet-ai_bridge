// Package main implements pe-capture: a tiny OpenAI-compatible HTTP server that
// records exactly what a client (Puppet Enterprise's AI Agent) sends, and either
// answers with a canned-but-valid response or forwards to a real upstream.
package main

import (
	"bytes"
	"crypto/subtle"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strings"
	"sync"
	"time"
)

// Options configures a Proxy.
type Options struct {
	// Models advertised on GET /v1/models. The first is used as the default.
	Models []string
	// Upstream, when set, is an OpenAI-compatible base URL (e.g. https://api.openai.com)
	// that requests are forwarded to after being logged. Empty = canned responses.
	Upstream string
	// UpstreamKey replaces the client's Authorization header when forwarding.
	UpstreamKey string
	// RewriteModel maps incoming model names to upstream model names.
	RewriteModel map[string]string
	// RequireKey, when set, is the bearer token clients must present.
	RequireKey string
	// MaxBodyBytes caps request bodies read into memory. 0 = 8 MiB.
	MaxBodyBytes int64
}

// Proxy is an http.Handler.
type Proxy struct {
	opts     Options
	upstream *url.URL
	client   *http.Client
	mu       sync.Mutex
	log      io.Writer
	now      func() time.Time
}

// NewProxy validates opts and returns a Proxy that writes JSON lines to logw.
func NewProxy(opts Options, logw io.Writer) (*Proxy, error) {
	if len(opts.Models) == 0 {
		opts.Models = []string{"o4-mini"}
	}
	if opts.MaxBodyBytes <= 0 {
		opts.MaxBodyBytes = 8 << 20
	}
	p := &Proxy{opts: opts, log: logw, now: time.Now,
		client: &http.Client{Timeout: 5 * time.Minute}}
	if opts.Upstream != "" {
		u, err := url.Parse(opts.Upstream)
		if err != nil || u.Scheme == "" || u.Host == "" {
			return nil, fmt.Errorf("invalid upstream URL %q", opts.Upstream)
		}
		p.upstream = u
	}
	return p, nil
}

type logLine struct {
	TS             string            `json:"ts"`
	RemoteAddr     string            `json:"remote_addr"`
	Method         string            `json:"method"`
	Path           string            `json:"path"`
	Query          string            `json:"query,omitempty"`
	Headers        map[string]string `json:"headers"`
	Body           json.RawMessage   `json:"body,omitempty"`
	BodyRaw        string            `json:"body_raw,omitempty"`
	ForwardedTo    string            `json:"forwarded_to,omitempty"`
	ForwardedModel string            `json:"forwarded_model,omitempty"`
	ResponseStatus int               `json:"response_status"`
	ResponseMS     int64             `json:"response_ms"`
	Error          string            `json:"error,omitempty"`
}

// ServeHTTP routes requests, logging everything except /healthz.
func (p *Proxy) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	if r.URL.Path == "/healthz" {
		w.Header().Set("Content-Type", "application/json")
		_, _ = w.Write([]byte(`{"status":"ok"}`))
		return
	}

	start := p.now()
	line := logLine{
		TS: start.UTC().Format(time.RFC3339Nano), RemoteAddr: r.RemoteAddr,
		Method: r.Method, Path: r.URL.Path, Query: r.URL.RawQuery,
		Headers: redactHeaders(r.Header),
	}
	body, err := io.ReadAll(io.LimitReader(r.Body, p.opts.MaxBodyBytes))
	if err != nil {
		line.Error = "read body: " + err.Error()
	}
	if json.Valid(body) {
		line.Body = json.RawMessage(body)
	} else if len(body) > 0 {
		line.BodyRaw = string(body)
	}

	rec := &statusRecorder{ResponseWriter: w, status: http.StatusOK}
	defer func() {
		line.ResponseStatus = rec.status
		line.ResponseMS = p.now().Sub(start).Milliseconds()
		p.writeLog(line)
	}()

	if p.opts.RequireKey != "" && !p.authorized(r) {
		writeError(rec, http.StatusUnauthorized, "invalid_api_key", "Incorrect API key provided.")
		return
	}

	if p.upstream != nil {
		p.forward(rec, r, body, &line)
		return
	}

	switch {
	case r.Method == http.MethodGet && r.URL.Path == "/v1/models":
		p.models(rec)
	case r.Method == http.MethodGet && strings.HasPrefix(r.URL.Path, "/v1/models/"):
		p.model(rec, strings.TrimPrefix(r.URL.Path, "/v1/models/"))
	case r.Method == http.MethodPost && r.URL.Path == "/v1/chat/completions":
		p.chat(rec, body)
	default:
		writeError(rec, http.StatusNotFound, "not_found",
			fmt.Sprintf("pe-capture: no canned handler for %s %s (request was logged)", r.Method, r.URL.Path))
	}
}

func (p *Proxy) authorized(r *http.Request) bool {
	got := strings.TrimPrefix(r.Header.Get("Authorization"), "Bearer ")
	return subtle.ConstantTimeCompare([]byte(got), []byte(p.opts.RequireKey)) == 1
}

func (p *Proxy) writeLog(l logLine) {
	b, err := json.Marshal(l)
	if err != nil {
		return
	}
	p.mu.Lock()
	defer p.mu.Unlock()
	_, _ = p.log.Write(append(b, '\n'))
}

// redactHeaders flattens headers and masks credentials, keeping a 4-char prefix
// so you can tell *which* key was sent without exposing it.
func redactHeaders(h http.Header) map[string]string {
	out := make(map[string]string, len(h))
	for k, v := range h {
		val := strings.Join(v, ", ")
		switch strings.ToLower(k) {
		case "authorization", "x-api-key", "api-key", "openai-api-key":
			val = redact(val)
		}
		out[k] = val
	}
	return out
}

func redact(v string) string {
	prefix := ""
	secret := v
	if strings.HasPrefix(v, "Bearer ") {
		prefix, secret = "Bearer ", strings.TrimPrefix(v, "Bearer ")
	}
	if len(secret) > 4 {
		secret = secret[:4]
	}
	return prefix + secret + "…[REDACTED]"
}

func (p *Proxy) models(w http.ResponseWriter) {
	type m struct {
		ID      string `json:"id"`
		Object  string `json:"object"`
		Created int64  `json:"created"`
		OwnedBy string `json:"owned_by"`
	}
	data := make([]m, 0, len(p.opts.Models))
	for _, id := range p.opts.Models {
		data = append(data, m{ID: id, Object: "model", Created: 1700000000, OwnedBy: "pe-capture"})
	}
	writeJSON(w, http.StatusOK, map[string]any{"object": "list", "data": data})
}

func (p *Proxy) model(w http.ResponseWriter, id string) {
	for _, m := range p.opts.Models {
		if m == id {
			writeJSON(w, http.StatusOK, map[string]any{"id": id, "object": "model", "created": 1700000000, "owned_by": "pe-capture"})
			return
		}
	}
	writeError(w, http.StatusNotFound, "model_not_found", fmt.Sprintf("The model `%s` does not exist", id))
}

func (p *Proxy) chat(w http.ResponseWriter, body []byte) {
	var req struct {
		Model  string `json:"model"`
		Stream bool   `json:"stream"`
	}
	_ = json.Unmarshal(body, &req)
	if req.Model == "" {
		req.Model = p.opts.Models[0]
	}
	id := fmt.Sprintf("chatcmpl-capture-%d", p.now().UnixNano())
	created := p.now().Unix()
	content := "pe-capture: request logged. This is a canned response; configure an upstream to get real answers."

	if req.Stream {
		w.Header().Set("Content-Type", "text/event-stream; charset=utf-8")
		w.Header().Set("Cache-Control", "no-cache")
		w.WriteHeader(http.StatusOK)
		chunk := func(delta map[string]any, finish any) {
			b, _ := json.Marshal(map[string]any{
				"id": id, "object": "chat.completion.chunk", "created": created, "model": req.Model,
				"choices": []map[string]any{{"index": 0, "delta": delta, "finish_reason": finish}},
			})
			_, _ = fmt.Fprintf(w, "data: %s\n\n", b)
		}
		chunk(map[string]any{"role": "assistant", "content": ""}, nil)
		chunk(map[string]any{"content": content}, nil)
		chunk(map[string]any{}, "stop")
		_, _ = io.WriteString(w, "data: [DONE]\n\n")
		return
	}

	writeJSON(w, http.StatusOK, map[string]any{
		"id": id, "object": "chat.completion", "created": created, "model": req.Model,
		"choices": []map[string]any{{
			"index":         0,
			"message":       map[string]any{"role": "assistant", "content": content},
			"finish_reason": "stop",
		}},
		"usage": map[string]int{"prompt_tokens": 0, "completion_tokens": 0, "total_tokens": 0},
	})
}

// forward relays the request to the upstream, rewriting the model name if configured.
func (p *Proxy) forward(w http.ResponseWriter, r *http.Request, body []byte, line *logLine) {
	outBody := body
	if len(p.opts.RewriteModel) > 0 && json.Valid(body) {
		var m map[string]any
		if err := json.Unmarshal(body, &m); err == nil {
			if model, ok := m["model"].(string); ok {
				if to, ok := p.opts.RewriteModel[model]; ok {
					m["model"] = to
					line.ForwardedModel = to
					if b, err := json.Marshal(m); err == nil {
						outBody = b
					}
				}
			}
		}
	}

	target := *p.upstream
	target.Path = strings.TrimRight(p.upstream.Path, "/") + r.URL.Path
	target.RawQuery = r.URL.RawQuery
	line.ForwardedTo = target.String()

	req, err := http.NewRequestWithContext(r.Context(), r.Method, target.String(), bytes.NewReader(outBody))
	if err != nil {
		line.Error = err.Error()
		writeError(w, http.StatusBadGateway, "upstream_error", err.Error())
		return
	}
	for k, v := range r.Header {
		switch strings.ToLower(k) {
		case "host", "content-length", "connection", "accept-encoding":
			continue
		}
		req.Header[k] = v
	}
	req.Host = target.Host
	if p.opts.UpstreamKey != "" {
		req.Header.Set("Authorization", "Bearer "+p.opts.UpstreamKey)
	}
	req.ContentLength = int64(len(outBody))

	resp, err := p.client.Do(req)
	if err != nil {
		line.Error = err.Error()
		writeError(w, http.StatusBadGateway, "upstream_error", err.Error())
		return
	}
	defer resp.Body.Close()
	for k, v := range resp.Header {
		w.Header()[k] = v
	}
	w.WriteHeader(resp.StatusCode)
	if f, ok := w.(http.Flusher); ok {
		// stream SSE through without buffering
		buf := make([]byte, 4096)
		for {
			n, rerr := resp.Body.Read(buf)
			if n > 0 {
				_, _ = w.Write(buf[:n])
				f.Flush()
			}
			if rerr != nil {
				break
			}
		}
		return
	}
	_, _ = io.Copy(w, resp.Body)
}

func parseRewrite(s string) (map[string]string, error) {
	out := map[string]string{}
	if strings.TrimSpace(s) == "" {
		return out, nil
	}
	for _, pair := range strings.Split(s, ",") {
		from, to, ok := strings.Cut(strings.TrimSpace(pair), "=")
		if !ok || from == "" || to == "" {
			return nil, fmt.Errorf("rewrite %q: expected from=to", pair)
		}
		out[from] = to
	}
	return out, nil
}

type statusRecorder struct {
	http.ResponseWriter
	status int
}

func (s *statusRecorder) WriteHeader(code int) {
	s.status = code
	s.ResponseWriter.WriteHeader(code)
}

func (s *statusRecorder) Flush() {
	if f, ok := s.ResponseWriter.(http.Flusher); ok {
		f.Flush()
	}
}

func writeJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(v)
}

func writeError(w http.ResponseWriter, status int, code, msg string) {
	writeJSON(w, status, map[string]any{"error": map[string]any{
		"message": msg, "type": "invalid_request_error", "code": code,
	}})
}
