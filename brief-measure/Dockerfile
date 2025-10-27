FROM rust:latest AS builder

WORKDIR /src
COPY Cargo.toml /src/
COPY migrations/ /src/migrations/
COPY src/ /src/src/
RUN cargo install --path . --root /usr/local

FROM builder AS brief-measure-migrate-up
ENTRYPOINT ["/usr/local/bin/brief-measure-migrate-up"]

FROM builder AS brief-measure-serve
ENTRYPOINT ["/usr/local/bin/brief-measure-serve"]
