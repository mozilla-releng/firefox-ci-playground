FROM ubuntu:jammy
LABEL maintainer="Ben Chatterton <bchatterton@mozilla.com>"

# Add worker user
RUN mkdir /builds && \
    adduser --home /builds/worker --shell /bin/bash --gecos "" --disabled-password worker && \
    mkdir /builds/worker/artifacts && \
    chown worker:worker /builds/worker/artifacts

# Update repositories
RUN apt update -y && apt upgrade -y

# Get apt packages for Py and Fx
RUN apt install python3-pip python-is-python3 git firefox -y

# Get pip packages
RUN pip install --no-cache --upgrade --break-system-packages pip setuptools
RUN pip install pipenv

# %include-run-task

ENV SHELL=/bin/bash \
    HOME=/builds/worker \
    PATH=/builds/worker/.local/bin:$PATH

VOLUME /builds/worker/checkouts
VOLUME /builds/worker/.cache

# Set a default command, useful for debugging
CMD ["/bin/bash"]
