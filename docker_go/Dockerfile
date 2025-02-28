# ビルドステージ
FROM golang:1.23-alpine3.21 AS builder
WORKDIR /app
COPY main.go .
RUN go mod init hello && go build -o hello

# ランタイムステージ
FROM alpine:latest
WORKDIR /app
COPY --from=builder /app/hello .
CMD ["./hello"]