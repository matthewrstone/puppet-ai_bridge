package main

import (
	"bufio"
	"bytes"
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func newTestProxy(t *testing.T, opts Options) (*Proxy, *bytes.Buffer) {
	t.Helper()
	var log bytes.Buffer
	if opts.Models == nil {
		opts.Models = []string{"o4-mini"}
	}
	p, err := NewProxy(opts, &log)
	if err != nil {
		t.Fatalf("NewProxy: %v", err)
	}
	return p, &log
}

func lastLogLine(t *testing.T, buf *bytes.Buffer) map[string]any {
	t.Helper()
	lines := strings.Split(strings.TrimSpace(buf.String()), "\n")
	var out map[string]any
	if err := json.Unmarshal([]byte(lines[len(lines)-1]), &out); err != nil {
		t.Fatalf("log line not JSON: %v\n%s", err, lines[len(lines)-1])
	}
	return out
}

func TestModelsListsConfiguredModels(t *testing.T) {
	p, _ := newTestProxy(t, Options{Models: []string{"o4-mini", "gpt-4o"}})
	rr := httptest.NewRecorder()
	p.ServeHTTP(rr, httptest.NewRequest(http.MethodGet, "/v1/models", nil))

	if rr.Code != http.StatusOK {
		t.Fatalf("status = %d, want 200", rr.Code)
	}
	var body struct {
		Object string `json:"object"`
		Data   []struct {
			ID     string `json:"id"`
			Object string `json:"object"`
		} `json:"data"`
	}
	if err := json.Unmarshal(rr.Body.Bytes(), &body); err != nil {
		t.Fatal(err)
	}
	if body.Object != "list" || len(body.Data) != 2 || body.Data[0].ID != "o4-mini" || body.Data[0].Object != "model" {
		t.Fatalf("unexpected models body: %s", rr.Body.String())
	}
}

func TestSingleModelGet(t *testing.T) {
	p, _ := newTestProxy(t, Options{})
	rr := httptest.NewRecorder()
	p.ServeHTTP(rr, httptest.NewRequest(http.MethodGet, "/v1/models/o4-mini", nil))
	if rr.Code != http.StatusOK {
		t.Fatalf("status = %d", rr.Code)
	}
	rr = httptest.NewRecorder()
	p.ServeHTTP(rr, httptest.NewRequest(http.MethodGet, "/v1/models/nope", nil))
	if rr.Code != http.StatusNotFound {
		t.Fatalf("unknown model status = %d, want 404", rr.Code)
	}
}

func TestChatCompletionCannedResponse(t *testing.T) {
	p, _ := newTestProxy(t, Options{})
	req := httptest.NewRequest(http.MethodPost, "/v1/chat/completions",
		strings.NewReader(`{"model":"o4-mini","messages":[{"role":"user","content":"ping"}]}`))
	req.Header.Set("Content-Type", "application/json")
	rr := httptest.NewRecorder()
	p.ServeHTTP(rr, req)

	if rr.Code != http.StatusOK {
		t.Fatalf("status = %d body=%s", rr.Code, rr.Body.String())
	}
	var body map[string]any
	if err := json.Unmarshal(rr.Body.Bytes(), &body); err != nil {
		t.Fatal(err)
	}
	if body["object"] != "chat.completion" || body["model"] != "o4-mini" {
		t.Fatalf("bad completion: %v", body)
	}
	choices := body["choices"].([]any)
	msg := choices[0].(map[string]any)["message"].(map[string]any)
	if msg["role"] != "assistant" || msg["content"] == "" {
		t.Fatalf("bad message: %v", msg)
	}
	if _, ok := body["usage"]; !ok {
		t.Fatal("usage missing")
	}
}

func TestChatCompletionStreaming(t *testing.T) {
	p, _ := newTestProxy(t, Options{})
	req := httptest.NewRequest(http.MethodPost, "/v1/chat/completions",
		strings.NewReader(`{"model":"o4-mini","stream":true,"messages":[]}`))
	rr := httptest.NewRecorder()
	p.ServeHTTP(rr, req)

	if ct := rr.Header().Get("Content-Type"); !strings.HasPrefix(ct, "text/event-stream") {
		t.Fatalf("content-type = %q", ct)
	}
	sc := bufio.NewScanner(rr.Body)
	var sawChunk, sawDone bool
	for sc.Scan() {
		line := sc.Text()
		if strings.HasPrefix(line, "data: {") {
			sawChunk = true
			var chunk map[string]any
			if err := json.Unmarshal([]byte(strings.TrimPrefix(line, "data: ")), &chunk); err != nil {
				t.Fatalf("chunk not JSON: %v", err)
			}
			if chunk["object"] != "chat.completion.chunk" {
				t.Fatalf("bad chunk object: %v", chunk)
			}
		}
		if line == "data: [DONE]" {
			sawDone = true
		}
	}
	if !sawChunk || !sawDone {
		t.Fatalf("stream incomplete: chunk=%v done=%v\n%s", sawChunk, sawDone, rr.Body.String())
	}
}

func TestLogLineCapturesRequestAndRedactsAuth(t *testing.T) {
	p, log := newTestProxy(t, Options{})
	req := httptest.NewRequest(http.MethodPost, "/v1/chat/completions?x=1",
		strings.NewReader(`{"model":"o4-mini","messages":[],"reasoning_effort":"low"}`))
	req.Header.Set("Authorization", "Bearer sk-supersecret")
	req.Header.Set("X-Custom", "keep-me")
	p.ServeHTTP(httptest.NewRecorder(), req)

	line := lastLogLine(t, log)
	if line["method"] != "POST" || line["path"] != "/v1/chat/completions" || line["query"] != "x=1" {
		t.Fatalf("bad line: %v", line)
	}
	hdrs := line["headers"].(map[string]any)
	if hdrs["Authorization"] != "Bearer sk-s…[REDACTED]" {
		t.Fatalf("auth not redacted: %v", hdrs["Authorization"])
	}
	if hdrs["X-Custom"] != "keep-me" {
		t.Fatalf("custom header lost: %v", hdrs)
	}
	body := line["body"].(map[string]any)
	if body["reasoning_effort"] != "low" {
		t.Fatalf("body not captured as JSON: %v", line["body"])
	}
	if _, ok := line["ts"]; !ok {
		t.Fatal("timestamp missing")
	}
	if line["response_status"] != float64(200) {
		t.Fatalf("response_status = %v", line["response_status"])
	}
}

func TestLogLineNonJSONBodyIsStoredRaw(t *testing.T) {
	p, log := newTestProxy(t, Options{})
	req := httptest.NewRequest(http.MethodPost, "/anything", strings.NewReader("not json"))
	p.ServeHTTP(httptest.NewRecorder(), req)
	line := lastLogLine(t, log)
	if line["body_raw"] != "not json" {
		t.Fatalf("raw body not stored: %v", line)
	}
}

func TestUnknownPathReturns404JSONError(t *testing.T) {
	p, _ := newTestProxy(t, Options{})
	rr := httptest.NewRecorder()
	p.ServeHTTP(rr, httptest.NewRequest(http.MethodGet, "/v1/nope", nil))
	if rr.Code != http.StatusNotFound {
		t.Fatalf("status = %d", rr.Code)
	}
	var body map[string]any
	if err := json.Unmarshal(rr.Body.Bytes(), &body); err != nil || body["error"] == nil {
		t.Fatalf("expected OpenAI-style error body, got %s", rr.Body.String())
	}
}

func TestHealthz(t *testing.T) {
	p, log := newTestProxy(t, Options{})
	rr := httptest.NewRecorder()
	p.ServeHTTP(rr, httptest.NewRequest(http.MethodGet, "/healthz", nil))
	if rr.Code != http.StatusOK {
		t.Fatalf("status = %d", rr.Code)
	}
	if log.Len() != 0 {
		t.Fatal("healthz should not be logged")
	}
}

func TestForwardToUpstreamWithModelRewrite(t *testing.T) {
	var gotBody map[string]any
	var gotAuth string
	upstream := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		gotAuth = r.Header.Get("Authorization")
		b, _ := io.ReadAll(r.Body)
		_ = json.Unmarshal(b, &gotBody)
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusTeapot)
		_, _ = w.Write([]byte(`{"from":"upstream"}`))
	}))
	defer upstream.Close()

	p, log := newTestProxy(t, Options{
		Upstream:     upstream.URL,
		UpstreamKey:  "sk-real",
		RewriteModel: map[string]string{"o4-mini": "gpt-5-mini"},
	})
	req := httptest.NewRequest(http.MethodPost, "/v1/chat/completions",
		strings.NewReader(`{"model":"o4-mini","messages":[]}`))
	req.Header.Set("Authorization", "Bearer pe-side-key")
	rr := httptest.NewRecorder()
	p.ServeHTTP(rr, req)

	if rr.Code != http.StatusTeapot || rr.Body.String() != `{"from":"upstream"}` {
		t.Fatalf("response not relayed: %d %s", rr.Code, rr.Body.String())
	}
	if gotBody["model"] != "gpt-5-mini" {
		t.Fatalf("model not rewritten: %v", gotBody)
	}
	if gotAuth != "Bearer sk-real" {
		t.Fatalf("upstream auth = %q", gotAuth)
	}
	line := lastLogLine(t, log)
	if line["forwarded_model"] != "gpt-5-mini" || line["response_status"] != float64(418) {
		t.Fatalf("log missing forward info: %v", line)
	}
}

func TestForwardWithoutRewriteKeepsModel(t *testing.T) {
	var gotModel string
	upstream := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		var b map[string]any
		_ = json.NewDecoder(r.Body).Decode(&b)
		gotModel, _ = b["model"].(string)
		_, _ = w.Write([]byte(`{}`))
	}))
	defer upstream.Close()
	p, _ := newTestProxy(t, Options{Upstream: upstream.URL})
	req := httptest.NewRequest(http.MethodPost, "/v1/chat/completions", strings.NewReader(`{"model":"o4-mini"}`))
	p.ServeHTTP(httptest.NewRecorder(), req)
	if gotModel != "o4-mini" {
		t.Fatalf("model = %q", gotModel)
	}
}

func TestRequireKeyRejectsBadBearer(t *testing.T) {
	p, log := newTestProxy(t, Options{RequireKey: "expected"})
	req := httptest.NewRequest(http.MethodGet, "/v1/models", nil)
	req.Header.Set("Authorization", "Bearer wrong")
	rr := httptest.NewRecorder()
	p.ServeHTTP(rr, req)
	if rr.Code != http.StatusUnauthorized {
		t.Fatalf("status = %d, want 401", rr.Code)
	}
	if lastLogLine(t, log)["response_status"] != float64(401) {
		t.Fatal("rejected request should still be logged")
	}

	req.Header.Set("Authorization", "Bearer expected")
	rr = httptest.NewRecorder()
	p.ServeHTTP(rr, req)
	if rr.Code != http.StatusOK {
		t.Fatalf("status with good key = %d", rr.Code)
	}
}

func TestParseRewriteFlag(t *testing.T) {
	m, err := parseRewrite("o4-mini=gpt-5-mini,o3=gpt-5")
	if err != nil || m["o4-mini"] != "gpt-5-mini" || m["o3"] != "gpt-5" {
		t.Fatalf("parse: %v %v", m, err)
	}
	if _, err := parseRewrite("broken"); err == nil {
		t.Fatal("expected error for missing '='")
	}
	m, err = parseRewrite("")
	if err != nil || len(m) != 0 {
		t.Fatalf("empty: %v %v", m, err)
	}
}

func TestInvalidUpstreamURLRejected(t *testing.T) {
	if _, err := NewProxy(Options{Upstream: "://bad"}, io.Discard); err == nil {
		t.Fatal("expected error")
	}
}
