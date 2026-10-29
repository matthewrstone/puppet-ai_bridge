FROM golang:1.24-alpine AS build
WORKDIR /src
COPY go.mod ./
COPY *.go ./
RUN CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /pe-capture .

FROM scratch
COPY --from=build /pe-capture /pe-capture
# ca-certificates needed only when -upstream is https to a public provider
COPY --from=build /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt
USER 65534:65534
VOLUME ["/data"]
EXPOSE 4000
ENTRYPOINT ["/pe-capture"]
CMD ["-listen", ":4000", "-log", "/data/capture.jsonl"]
