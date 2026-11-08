# NAS：基于 Extended 根 Dockerfile 构建，再叠加 houjia pref
# 用法见 deploy/nas/deploy-to-qnap.sh
ARG BASE_IMAGE=subconverter-extended-build
FROM ${BASE_IMAGE}
COPY deploy/nas/pref.build.toml /base/pref.toml
COPY deploy/nas/config-template.ini /base/config/houjia.local-template.ini
COPY deploy/nas/all_base.tpl /base/base/all_base.tpl
# 旧运行基底镜像自带 houjia-template.ini；2026-11-08 起内置模板合并为 houjia.local-template.ini，旧名删除
RUN rm -f /base/config/houjia-template.ini
WORKDIR /base
EXPOSE 25500/tcp
CMD ["/usr/local/bin/start-subconverter"]
