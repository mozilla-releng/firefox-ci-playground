FROM ubuntu:jammy
LABEL maintainer="Ben Chatterton <bchatterton@mozilla.com>"

# Add worker user
RUN mkdir /builds && \
    adduser --home /builds/worker --shell /bin/bash --disabled-password --gecos "" worker && \
    mkdir /builds/worker/artifacts && \
    chown worker:worker /builds/worker/artifacts

# Update repositories
RUN apt update -y && apt upgrade -y

# Setup deps
RUN apt install -y git python3-pip python-is-python3 firefox && \
    python -m pip install --no-cache --upgrade --break-system-packages pip setuptools pytest selenium

ENV PATH=/root/.local/bin:$PATH

# %include-run-task

ENV SHELL=/bin/bash \
    HOME=/builds/worker \
    PATH=/builds/worker/.local/bin:/root/.local/bin:$PATH

VOLUME /builds/worker/checkouts
VOLUME /builds/worker/.cache

# Set a default command useful for debugging
CMD ["/bin/bash"]
