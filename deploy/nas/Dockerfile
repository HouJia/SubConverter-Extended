# NAS 用镜像：官方运行时 + 本仓库 pref（max_allowed_rulesets=256）
# 构建（仓库根目录）：
#   docker buildx build --platform linux/amd64 -f deploy/nas/Dockerfile -t subconverter:nas-amd64 --load .
FROM tindy2013/subconverter:latest
COPY deploy/nas/pref.toml /base/pref.toml
COPY deploy/nas/config-template.ini /base/config/houjia-template.ini
