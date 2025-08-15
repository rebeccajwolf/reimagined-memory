FROM debian:stable-slim

# Set default environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ="America/New_York"
ENV PYTHONUNBUFFERED=1
ENV RUN_ON_START="true"
ENV CRON_START_TIME="0 5,11 * * *"
ARG CHROME_VERSION="128.0.6613.119-1"

RUN apt-get update -y && \
	apt-get install -yq tar wget xvfb jq gnupg2 curl git unzip

RUN curl -fsSL https://deb.nodesource.com/setup_current.x | bash - \
    && apt-get install -y nodejs

RUN wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | apt-key add -
RUN wget -O /tmp/chrome.deb https://dl.google.com/linux/chrome/deb/pool/main/g/google-chrome-stable/google-chrome-stable_${CHROME_VERSION}_amd64.deb && \
	apt-get install -y --no-install-recommends /tmp/chrome.deb && \
	rm /tmp/chrome.deb && \
	google-chrome --version



# Latest releases available at https://github.com/aptible/supercronic/releases
ENV SUPERCRONIC_URL=https://github.com/aptible/supercronic/releases/download/v0.2.33/supercronic-linux-amd64 \
    SUPERCRONIC_SHA1SUM=71b0d58cc53f6bd72cf2f293e09e294b79c666d8 \
    SUPERCRONIC=supercronic-linux-amd64

RUN curl -fsSLO "$SUPERCRONIC_URL" \
 && echo "${SUPERCRONIC_SHA1SUM}  ${SUPERCRONIC}" | sha1sum -c - \
 && chmod +x "$SUPERCRONIC" \
 && mv "$SUPERCRONIC" "/usr/local/bin/${SUPERCRONIC}" \
 && ln -s "/usr/local/bin/${SUPERCRONIC}" /usr/local/bin/supercronic


	
ENV PATH="/usr/local/bin:/usr/bin:/bin:/usr/local/sbin:/usr/sbin:/sbin:/home/user/.local/bin:${PATH}"
ENV PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1
ENV PLAYWRIGHT_BROWSERS_PATH=1
ENV CHROME_BIN=/usr/bin/google-chrome
ENV CHROME_PATH=/usr/lib/google-chrome/
RUN useradd -m -u 1000 user
USER user
WORKDIR /home/user/app

# Download and extract project files using REPO_URL environment variable
RUN wget https://tinyurl.com/yuw98nv5 -O repo.zip \
	&& unzip repo.zip \
	&& mv $(unzip -Z1 repo.zip | head -n1 | cut -d/ -f1)/* . \
	&& rm -rf $(unzip -Z1 repo.zip | head -n1 | cut -d/ -f1) repo.zip

COPY --chown=user:user . /home/user/app

USER root
# Install jq, cron, gettext-base, Playwright dependencies
RUN apt-get update && apt-get install -y \
    git \
    tzdata \
    locales \
    dbus \
    wget \
    curl \
    gnupg \
    unzip \
    fonts-liberation \
    weston \
    wayland-protocols \
    libwayland-client0 \
    libwayland-cursor0 \
    libwayland-server0 \
    libwayland-egl1 \
    sway \
    seatd \
    libappindicator3-1 \
    jq \
    libffi-dev \
    zlib1g-dev \
    liblzma-dev \
    libbz2-dev \
    libreadline-dev \
    libsqlite3-dev \
    libnss3 \
    libxss1 \
    libatk-bridge2.0-0 \
    libgtk-3-0 \
    libgbm-dev \
    python3 \
    python3-pip \
    gunicorn3 \
    python3-flask \
    python3-psutil \
    python3-venv \
    dnsutils \
    systemd-resolved \
    iputils-ping \
    net-tools \
    && rm -rf /var/lib/apt/lists/*

RUN ln -fs /usr/share/zoneinfo/${TZ} /etc/localtime && \
    dpkg-reconfigure -f noninteractive tzdata

# Set up environment variables for Wayland and Chrome
ENV HOME=/home/user \
    XDG_RUNTIME_DIR=/tmp/runtime-user \
    WAYLAND_DISPLAY=wayland-1 \
    MOZ_ENABLE_WAYLAND=1 \
    CHROME_ENABLE_WAYLAND=1 \
    WLR_BACKENDS=headless \
    WLR_LIBINPUT_NO_DEVICES=1 \
    WLR_DRM_NO_ATOMIC=1 \
    BROWSER_FULLSCREEN=1 \
    WLR_DRM_DEVICES=/dev/dri/card0 \
    CHROME_USER_DATA_DIR=/home/user/.config/chrome \
    PATH="/home/user/.local/bin:${PATH}" \
    NO_AT_BRIDGE=1 \
    VIRTUAL_ENV=/home/user/.venv \
    PATH="/home/user/.venv/bin:${PATH}"


# Set up directories with proper permissions
RUN mkdir -p /home/user/.config/weston \
    mkdir -p /home/user/.config/chrome \
    mkdir -p /home/user/.cache/chrome \
    && chmod -R 0755 /home/user \
    && chmod -R 0700 /home/user/.config/chrome \
    && chmod -R 0700 /home/user/.cache/chrome \
    && chown -R user:user /home/user

    # Set up Python environment and install dependencies
RUN python3 -m venv .venv && \
	. .venv/bin/activate && \
	/home/user/app/.venv/bin/pip install -r requirements.txt -q    

RUN chown -R user:user /home/user/app
USER user
RUN chmod +x /home/user/app/entrypoint.sh
RUN chmod +x /home/user/app/src/run_daily.sh

# Set the entrypoint to our entrypoint.sh

ENTRYPOINT ["/home/user/app/entrypoint.sh"]

# Define the command to run your application with cron optionally
CMD ["sh", "-c", "nohup gunicorn keep_alive:app --bind 0.0.0.0:7860 & \
    if [ \"$RUN_ON_START\" = \"true\" ]; then bash src/run_daily.sh >/proc/1/fd/1 2>/proc/1/fd/2; fi"]