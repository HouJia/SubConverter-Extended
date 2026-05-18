# NAS：从本仓库源码构建（VLESS/TUIC + hjs pref）
#   docker buildx build --platform linux/amd64 -f deploy/nas/Dockerfile -t subconverter:nas-amd64 --load .
FROM alpine:3.16 AS builder
ARG THREADS=4
WORKDIR /

RUN set -xe && \
    apk add --no-cache --virtual .build-tools git g++ build-base linux-headers cmake python3 py3-pip && \
    apk add --no-cache --virtual .build-deps curl-dev rapidjson-dev pcre2-dev yaml-cpp-dev && \
    git clone https://github.com/ftk/quickjspp --depth=1 && \
    cd quickjspp && git submodule update --init && \
    cmake -DCMAKE_BUILD_TYPE=Release . && make quickjs -j ${THREADS} && \
    install -d /usr/lib/quickjs/ && install -m644 quickjs/libquickjs.a /usr/lib/quickjs/ && \
    install -d /usr/include/quickjs/ && \
    install -m644 quickjs/quickjs.h quickjs/quickjs-libc.h /usr/include/quickjs/ && \
    install -m644 quickjspp.hpp /usr/include && cd .. && \
    git clone https://github.com/PerMalmberg/libcron --depth=1 && \
    cd libcron && git submodule update --init && \
    cmake -DCMAKE_BUILD_TYPE=Release . && make libcron -j ${THREADS} && \
    install -m644 libcron/out/Release/liblibcron.a /usr/lib/ && \
    install -d /usr/include/libcron/ && install -m644 libcron/include/libcron/* /usr/include/libcron/ && \
    install -d /usr/include/date/ && install -m644 libcron/externals/date/include/date/* /usr/include/date/ && cd .. && \
    git clone https://github.com/ToruNiina/toml11 --branch=v4.3.0 --depth=1 && \
    cd toml11 && cmake -DCMAKE_CXX_STANDARD=11 . && make install -j ${THREADS}

COPY . /subconverter
WORKDIR /subconverter
RUN python3 -m pip install --no-cache-dir gitpython && \
    python3 scripts/update_rules.py -c scripts/rules_config.conf && \
    cmake -DCMAKE_BUILD_TYPE=Release . && make -j ${THREADS}

FROM alpine:3.16
RUN apk add --no-cache pcre2 libcurl yaml-cpp tzdata
COPY --from=builder /subconverter/subconverter /base/subconverter
COPY --from=builder /subconverter/base /base/
COPY deploy/nas/pref.toml /base/pref.toml
COPY deploy/nas/config-template.ini /base/config/houjia-template.ini
ENV TZ=Asia/Shanghai
WORKDIR /base
EXPOSE 25500/tcp
CMD ["./subconverter"]
