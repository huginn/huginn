FROM ghcr.io/huginn/huginn-single-process

USER 0

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      ca-certificates \
      curl \
      gnupg \
      unzip \
    && \
    curl -fsSL https://dl.google.com/linux/linux_signing_key.pub | gpg --dearmor -o /usr/share/keyrings/google-linux.gpg && \
    echo 'deb [arch=amd64 signed-by=/usr/share/keyrings/google-linux.gpg] https://dl.google.com/linux/chrome/deb/ stable main' > /etc/apt/sources.list.d/google-chrome.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends google-chrome-stable && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

RUN set -eux; \
    chrome_version="$(google-chrome-stable --product-version)"; \
    chrome_build="${chrome_version%.*}"; \
    json="$(mktemp)"; \
    chromedriver_zip="$(mktemp)"; \
    curl -fsSL -o "$json" https://googlechromelabs.github.io/chrome-for-testing/latest-patch-versions-per-build-with-downloads.json; \
    chromedriver_url="$(jq -r --arg build "$chrome_build" '.builds[$build].downloads.chromedriver[] | select(.platform == "linux64") | .url' "$json")"; \
    test -n "$chromedriver_url"; \
    curl -fsSL -o "$chromedriver_zip" "$chromedriver_url"; \
    unzip -q "$chromedriver_zip" -d /opt; \
    ln -sf /opt/chromedriver-linux64/chromedriver /usr/local/bin/chromedriver; \
    google-chrome-stable --version; \
    chromedriver --version; \
    rm -f "$json" "$chromedriver_zip"

ENV CHROME_BIN=/usr/bin/google-chrome-stable
ENV RAILS_ENV=test

COPY --chown=1001:0 --chmod=755 docker/test/scripts/test_env /scripts/
USER 1001
ENTRYPOINT ["/scripts/test_env"]
CMD ["bundle", "exec", "rake"]
