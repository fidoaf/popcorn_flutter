FROM dart:stable

WORKDIR /app
COPY packages/popcorn_server_core ./packages/popcorn_server_core
COPY packages/popcorn_server_runtime ./packages/popcorn_server_runtime
COPY assets/config/server_media_source_providers.json ./assets/config/server_media_source_providers.json

WORKDIR /app/packages/popcorn_server_runtime
RUN dart pub get

ENV HOST=0.0.0.0 PORT=3000
EXPOSE 3000
CMD ["dart", "run", "bin/server.dart"]