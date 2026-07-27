# Pinned to an exact release: Bifrost ships often, and a moving tag turns every
# restart into a different version of your gateway.
FROM maximhq/bifrost:v1.6.6

USER root
COPY config.json /app/config.template.json
COPY docker/render-config.sh /app/render-config.sh
RUN chmod +x /app/render-config.sh && chmod 0444 /app/config.template.json
USER 1000:0

# The upstream entrypoint expects its configuration to already be on disk, so
# ours puts it there and then hands over unchanged.
ENTRYPOINT ["/app/render-config.sh"]
CMD ["/app/main"]
