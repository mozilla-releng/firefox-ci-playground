FROM --platform=linux/x86_64 ubuntu:jammy
LABEL maintainer="Ben Chatterton <bchatterton@mozilla.com>"

# Add worker user
RUN mkdir /builds && \
    adduser --home /builds/worker --shell /bin/bash --disabled-password --gecos "" worker && \
    mkdir /builds/worker/artifacts && \
    chown worker:worker /builds/worker/artifacts && \
    chown worker:worker /root && \
    chmod u+w /root


# Update repositories
RUN apt update -y && apt upgrade -y

# Setup deps
RUN apt install -y git python3-pip python-is-python3 firefox unzip && \
    apt install -y wget bzip2 libxtst6 libgtk-3-0 libx11-xcb-dev libdbus-glib-1-2 libxt6 libpci-dev && \
    rm -rf /var/lib/apt/lists/* && \
    python -m pip install --no-cache --upgrade pip setuptools pytest selenium

ENV PATH=/root/.local/bin:$PATH

# %include-run-task
# %include firefox.tar.bz2
# %include geckodriver.tar.gz
ADD topsrcdir/firefox.tar.bz2 /root/
ADD topsrcdir/geckodriver.tar.gz /root/
RUN ls /root/

RUN tar xvf /root/firefox.tar.bz2 -C /root/.local/bin/
ENV PATH=/root/.local/bin/firefox:$PATH
RUN tar xvf /root/geckodriver.tar.gz -C root/.local/bin/

ENV SHELL=/bin/bash \
    HOME=/builds/worker \
    PATH=/builds/worker/.local/bin:/root/.local/bin:$PATH

VOLUME /builds/worker/checkouts
VOLUME /builds/worker/.cache

# Set a default command useful for debugging
CMD ["/bin/bash"]
