# Build stage
FROM rust:1-bookworm AS builder

WORKDIR /app

# Copy manifests and source
COPY Cargo.toml Cargo.lock ./
COPY src ./src
COPY migrations ./migrations

# Build release binary (migrations are embedded at compile time)
RUN cargo build --release

# Runtime stage
FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    libpq5 \
    libssl3 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy the built binary from builder
COPY --from=builder /app/target/release/wetty-chat-backend /app/wetty-chat-backend

# Server listens on 3000
EXPOSE 3000

# DATABASE_URL must be set at runtime (e.g. via docker run -e or compose environment)
ENV RUST_LOG=info

ENTRYPOINT ["/app/wetty-chat-backend"]
