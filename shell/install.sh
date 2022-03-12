
# cp ./sources.list /etc/apt/sources.list
# apt-get update

# RESTY_DEB_FLAVOR build argument is used to select other
# OpenResty Debian package variants.
# For example: "-debug" or "-valgrind"
RESTY_DEB_FLAVOR=""
RESTY_DEB_VERSION="=1.19.9.1-1~bullseye1"
RESTY_APT_REPO="https://openresty.org/package/debian"
RESTY_APT_PGP="https://openresty.org/package/pubkey.gpg"
RESTY_IMAGE_BASE="debian"
RESTY_IMAGE_TAG="bullseye-slim"

resty_image_base="${RESTY_IMAGE_BASE}"
resty_image_tag="${RESTY_IMAGE_TAG}"
resty_apt_repo="${RESTY_APT_REPO}"
resty_apt_pgp="${RESTY_APT_PGP}"
resty_deb_flavor="${RESTY_DEB_FLAVOR}"
resty_deb_version="${RESTY_DEB_VERSION}"


DEBIAN_FRONTEND=noninteractive apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        ca-certificates \
        gettext-base \
        gnupg2 \
        lsb-base \
        lsb-release \
        software-properties-common \
        wget \
    && wget -qO /tmp/pubkey.gpg ${RESTY_APT_PGP} \
    && DEBIAN_FRONTEND=noninteractive apt-key add /tmp/pubkey.gpg \
    && rm /tmp/pubkey.gpg \
    && DEBIAN_FRONTEND=noninteractive add-apt-repository -y "deb ${RESTY_APT_REPO} $(lsb_release -sc) openresty" \
    && DEBIAN_FRONTEND=noninteractive apt-get remove -y --purge \
        gnupg2 \
        lsb-release \
        software-properties-common \
        wget \
    && DEBIAN_FRONTEND=noninteractive apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        openresty${RESTY_DEB_FLAVOR}${RESTY_DEB_VERSION} \
    && DEBIAN_FRONTEND=noninteractive apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /var/run/openresty \
    && ln -sf /dev/stdout /usr/local/openresty${RESTY_DEB_FLAVOR}/nginx/logs/access.log \
    && ln -sf /dev/stderr /usr/local/openresty${RESTY_DEB_FLAVOR}/nginx/logs/error.log

ln -s $PWD/../ /luojia

# Add additional binaries into PATH for convenience
PATH="$PATH:/usr/local/openresty${RESTY_DEB_FLAVOR}/luajit/bin:/usr/local/openresty${RESTY_DEB_FLAVOR}/nginx/sbin:/usr/local/openresty${RESTY_DEB_FLAVOR}/bin"