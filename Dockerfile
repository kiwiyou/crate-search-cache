FROM ekidd/rust-musl-builder:stable as builder

RUN USER=root cargo new --bin crate-search-cache
WORKDIR ./crate-search-cache
COPY ./Cargo.lock ./Cargo.lock
COPY ./Cargo.toml ./Cargo.toml
RUN cargo build --release
RUN rm src/*.rs

ADD src/* ./src

RUN rm ./target/x86_64-unknown-linux-musl/release/deps/crate_search_cache* && cargo build --release


FROM alpine:latest

ARG APP=/usr/src/app

EXPOSE 80

ENV TZ=Etc/UTC \
    APP_USER=appuser

RUN addgroup -S $APP_USER \
    && adduser -S -g $APP_USER $APP_USER

RUN apk update \
    && apk add --no-cache ca-certificates tzdata wget postgresql-client \
    && rm -rf /var/cache/apk/*

COPY --from=builder /home/rust/src/crate-search-cache/target/x86_64-unknown-linux-musl/release/crate-search-cache ${APP}/crate-search-cache
COPY update.sh ${APP}/update.sh

RUN chown -R $APP_USER:$APP_USER ${APP}

USER $APP_USER
WORKDIR ${APP}

CMD ["./crate-search-cache"]