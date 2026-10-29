package main

import (
	"flag"
	"fmt"
	"log"
	"net/http"
	"os"
	"strings"
	"time"
)

func main() {
	var (
		listen   = flag.String("listen", ":4000", "address to listen on")
		logPath  = flag.String("log", "capture.jsonl", "JSONL file to append captured requests to ('-' for stdout)")
		models   = flag.String("models", "o4-mini", "comma-separated model IDs to advertise")
		upstream = flag.String("upstream", "", "optional OpenAI-compatible base URL to forward to (e.g. https://api.openai.com)")
		upKey    = flag.String("upstream-key", os.Getenv("PE_CAPTURE_UPSTREAM_KEY"), "bearer token for upstream (env PE_CAPTURE_UPSTREAM_KEY)")
		rewrite  = flag.String("rewrite-model", "", "model rewrites when forwarding, e.g. o4-mini=gpt-5-mini,o3=gpt-5")
		reqKey   = flag.String("require-key", os.Getenv("PE_CAPTURE_REQUIRE_KEY"), "if set, clients must send this bearer token (env PE_CAPTURE_REQUIRE_KEY)")
		cert     = flag.String("cert", "", "TLS certificate file (PEM). Omit for plain HTTP")
		key      = flag.String("key", "", "TLS private key file (PEM)")
	)
	flag.Parse()

	rw, err := parseRewrite(*rewrite)
	if err != nil {
		log.Fatal(err)
	}

	var logw *os.File
	if *logPath == "-" {
		logw = os.Stdout
	} else {
		logw, err = os.OpenFile(*logPath, os.O_CREATE|os.O_APPEND|os.O_WRONLY, 0o600)
		if err != nil {
			log.Fatalf("open log: %v", err)
		}
		defer logw.Close()
	}

	p, err := NewProxy(Options{
		Models:       strings.Split(*models, ","),
		Upstream:     *upstream,
		UpstreamKey:  *upKey,
		RewriteModel: rw,
		RequireKey:   *reqKey,
	}, logw)
	if err != nil {
		log.Fatal(err)
	}

	srv := &http.Server{
		Addr:              *listen,
		Handler:           p,
		ReadHeaderTimeout: 10 * time.Second,
		IdleTimeout:       120 * time.Second,
	}

	mode := "canned responses"
	if *upstream != "" {
		mode = "forwarding to " + *upstream
	}
	fmt.Fprintf(os.Stderr, "pe-capture listening on %s (%s), logging to %s\n", *listen, mode, *logPath)

	if *cert != "" || *key != "" {
		if *cert == "" || *key == "" {
			log.Fatal("both -cert and -key are required for TLS")
		}
		log.Fatal(srv.ListenAndServeTLS(*cert, *key))
	}
	log.Fatal(srv.ListenAndServe())
}
