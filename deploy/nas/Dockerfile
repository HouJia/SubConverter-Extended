# NAS：从本仓库源码构建（含 MetaCubeX 合并的 VLESS/TUIC/Reality）+ 挂载 pref/模板
# 构建（仓库根目录）：
#   docker buildx build --platform linux/amd64 -f deploy/nas/Dockerfile -t subconverter:nas-amd64 --load .
#
# 仅更新配置、仍用上游预编译二进制时见 deploy/nas/Dockerfile.overlay
FROM alpine:3.16 AS builder
ARG THREADS=4
WORKDIR /src
COPY . /src
RUN set -xe && \
    apk add --no-cache gcc g++ build-base linux-headers cmake make autoconf automake libtool \
        python3 py3-pip mbedtls-dev mbedtls-static zlib-dev rapidjson-dev zlib-static pcre2-dev git && \
    bash scripts/build.alpine.release.sh

FROM alpine:3.16
RUN apk add --no-cache pcre2 libcurl yaml-cpp tzdata
COPY --from=builder /src/subconverter /base/
COPY deploy/nas/pref.toml /base/pref.toml
COPY deploy/nas/config-template.ini /base/config/houjia-template.ini
ENV TZ=Asia/Shanghai
WORKDIR /base
EXPOSE 25500/tcp
CMD ["./subconverter"]
