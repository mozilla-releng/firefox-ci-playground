FROM alpine:latest
LABEL maintainer="Ben Chatterton <bchatterton@mozilla.com>"

# Add worker user
RUN mkdir /builds && \
    adduser -h /builds/worker -s /bin/ash -D worker && \
    mkdir /builds/worker/artifacts && \
    chown worker:worker /builds/worker/artifacts

# Update repositories
RUN apk update

# Setup Python
RUN apk add --no-cache python3 py3-pip && \
    python3 -m pip install --no-cache --upgrade --break-system-packages pip setuptools

# Setup other dependencies
RUN apk add bash git pipx
ENV PATH=/root/.local/bin:$PATH
RUN PIPX_HOME=/opt/pipx PIPX_BIN_DIR=/usr/local/bin pipx install pipenv

# For Now: Install Firefox from apk repo
RUN apk add --no-cache firefox-esr

# Install Geckodriver
SHELL ["/bin/ash", "-eo", "pipefail", "-c"]
RUN apk add --no-cache --virtual .build-deps wget \
    && GECKODRIVER_VERSION=$(wget -qO- https://api.github.com/repos/mozilla/geckodriver/releases/latest \
    | grep "tag_name" | sed -E 's/.*"([^"]+)".*/\1/') \
    && wget -qO /tmp/geckodriver.tar.gz \
    "https://github.com/mozilla/geckodriver/releases/download/$GECKODRIVER_VERSION/geckodriver-$GECKODRIVER_VERSION-linux64.tar.gz" \
    && tar -xzf /tmp/geckodriver.tar.gz -C /usr/local/bin/ \
    && rm /tmp/geckodriver.tar.gz \
    && apk del .build-deps

# %include-run-task

ENV SHELL=/bin/ash \
    HOME=/builds/worker \
    PATH=/builds/worker/.local/bin:/root/.local/bin:$PATH

VOLUME /builds/worker/checkouts
VOLUME /builds/worker/.cache

# Set a default command useful for debugging
CMD ["/bin/ash"]
