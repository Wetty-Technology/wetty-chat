# Build stage
FROM --platform=$BUILDPLATFORM rust:1.94.0-trixie AS builder

ARG TARGETARCH

# Install cross-compilation toolchain and C dependencies
RUN dpkg --add-architecture arm64 && \
    dpkg --add-architecture amd64 && \
    apt-get update && apt-get install -y --no-install-recommends \
    gcc-aarch64-linux-gnu \
    g++-aarch64-linux-gnu \
    libc6-dev-arm64-cross \
    pkg-config \
    libmariadb-dev:${TARGETARCH} \
    libpq-dev:${TARGETARCH} \
    libssl-dev:${TARGETARCH} \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Map Docker TARGETARCH to Rust triple and pkg-config libdir
RUN if [ "$TARGETARCH" = "arm64" ]; then \
        echo "aarch64-unknown-linux-gnu" > /app/target-triple.txt && \
        echo "aarch64-linux-gnu-gcc" > /app/cargo-linker.txt && \
        echo "/usr/lib/aarch64-linux-gnu/pkgconfig" > /app/pkg-config-libdir.txt && \
        rustup target add aarch64-unknown-linux-gnu; \
    elif [ "$TARGETARCH" = "amd64" ]; then \
        echo "x86_64-unknown-linux-gnu" > /app/target-triple.txt && \
        echo "gcc" > /app/cargo-linker.txt && \
        echo "/usr/lib/x86_64-linux-gnu/pkgconfig" > /app/pkg-config-libdir.txt && \
        rustup target add x86_64-unknown-linux-gnu; \
    else \
        echo "Unsupported architecture: $TARGETARCH" && exit 1; \
    fi

# Copy manifests and source
COPY Cargo.toml Cargo.lock ./
COPY src ./src
COPY migrations ./migrations

# Build release binary (migrations are embedded at compile time)
RUN export TARGET_TRIPLE=$(cat /app/target-triple.txt) && \
    export LINKER=$(cat /app/cargo-linker.txt) && \
    export PKG_CONFIG_ALLOW_CROSS=1 && \
    export PKG_CONFIG_SYSROOT_DIR=/ && \
    export PKG_CONFIG_LIBDIR=$(cat /app/pkg-config-libdir.txt):/usr/share/pkgconfig && \
    if [ "$TARGETARCH" = "arm64" ]; then \
        export CARGO_TARGET_AARCH64_UNKNOWN_LINUX_GNU_LINKER=$LINKER; \
    else \
        export CARGO_TARGET_X86_64_UNKNOWN_LINUX_GNU_LINKER=$LINKER; \
    fi && \
    cargo build --release --target $TARGET_TRIPLE && \
    cp target/$TARGET_TRIPLE/release/wetty-chat-backend /app/wetty-chat-backend

# Runtime stage
FROM debian:trixie-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    libmariadb-dev \
    libpq5 \
    libssl3 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy the built binary from builder
COPY --from=builder /app/wetty-chat-backend /app/wetty-chat-backend

# Server listens on 3000 and exposes Prometheus metrics on 3001
EXPOSE 3000
EXPOSE 3001

# DATABASE_URL must be set at runtime (e.g. via docker run -e or compose environment)
ENV RUST_LOG=info

ENTRYPOINT ["/app/wetty-chat-backend"]
