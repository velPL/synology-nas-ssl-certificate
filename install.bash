#!/bin/bash

<<comment
    Automated acme.sh provisioning for Synology NAS with ZeroSSL free certificate generation using DNS challenge via CloudFlare domain provider
    Version: 0.1.0
comment

# Variables
ZEROSSL_HELP_URL='https://help.zerossl.com/hc/en-us/articles/360060120053-Troubleshooting-Email-Verification'
ACME_SCRIPT_DEFAULT_INSTALL_DIR='/usr/local/share/acme.sh'
ACME_SCRIPT_DOWNLOAD_URL_TEMPLATE='https://github.com/acmesh-official/acme.sh/archive/refs/heads/master.zip'
CERTIFICATE_CONFIG_FILE=account.conf
SYNOLOGY_CERTIFICATE_PATH='/var/services/homes/certificate/.acme.sh'
TEMP_DIR='/tmp'
UNZIP_COMMAND='7zz'

# Functions
print_error() {
  echo "\033[0;31m❌ An error occurred: \033[0m$1"
}
print_success() {
  echo "\033[0;32m✅ Success: \033[0m$1"
}

# Pre-checks
if ! command -v curl >/dev/null && ! command -v wget >/dev/null; then
    print_error "You need curl or wget to be present on your Synology NAS"
    exit 1
fi
if ! command -v "${UNZIP_COMMAND}" >/dev/null; then
    print_error "You need 7z to be present on your Synology NAS"
    exit 1
fi
if [[ ! -n "${HOME}" || ! -d "${HOME}" ]]; then
    print_error "User has no home directory - did you enable users' home folder in you Synology NAS?"
    exit 1
fi
if [ ! -w "${TEMP_DIR}" ]; then
    print_error "The /tmp folder is not writable by current user."
    exit 1
fi

# Gather user inputs for installation
read -p "Where to install acme.sh (leave empty for default ${ACME_SCRIPT_DEFAULT_INSTALL_DIR})?: " ACME_SCRIPT_INSTALL_DIR
if [ -z "${ACME_SCRIPT_INSTALL_DIR}" ]
then
    ACME_SCRIPT_INSTALL_DIR="${ACME_SCRIPT_DEFAULT_INSTALL_DIR}"
fi
ACME_SCRIPT_INSTALL_DIR=$(realpath ${ACME_SCRIPT_INSTALL_DIR})
ACME_SCRIPT_INSTALL_DIR="${ACME_SCRIPT_INSTALL_DIR%/}"
if [[ -d ${ACME_SCRIPT_INSTALL_DIR} && -f "${ACME_SCRIPT_INSTALL_DIR}/${CERTIFICATE_CONFIG_FILE}" ]]
then
    print_error "There is already an existing and configured instance in this folder - ABORTING"
    exit 1
fi


read -p "Enter version numer of acme.sh you want to install (empty means latest master): " ACME_INSTALL_VERSION
if [ ! -z "${ACME_INSTALL_VERSION}" ]
then
    ACME_SCRIPT_DOWNLOAD_URL_TEMPLATE="https://github.com/acmesh-official/acme.sh/archive/refs/tags/${ACME_INSTALL_VERSION}.zip"
else
    ACME_INSTALL_VERSION='master'
fi

# Download acme.sh and make it executable
echo "⏳ Will now install version ${ACME_INSTALL_VERSION} into ${ACME_SCRIPT_INSTALL_DIR}"

if [ ! -d "${ACME_SCRIPT_INSTALL_DIR}" ]; then
    mkdir -p "${ACME_SCRIPT_INSTALL_DIR}" || {
        print_error "Cannot create directory $ACME_SCRIPT_INSTALL_DIR"
        exit 1
    }
fi

if command -v curl >/dev/null 2>&1; then
    curl -fsSL "${ACME_SCRIPT_DOWNLOAD_URL_TEMPLATE}" -o "${TEMP_DIR}/acme.sh.zip" || {
        print_error "Download failed with curl."
        exit 1
    }
elif command -v wget >/dev/null 2>&1; then
    wget -O "${TEMP_DIR}/acme.sh.zip" "${ACME_SCRIPT_DOWNLOAD_URL_TEMPLATE}" || {
        print_error "ERROR: Download failed with wget."
        exit 1
    }
fi
${UNZIP_COMMAND} x  -o"${TEMP_DIR}" "${TEMP_DIR}/acme.sh.zip"
mv -f "${TEMP_DIR}/acme.sh-${ACME_INSTALL_VERSION}/"* "${ACME_SCRIPT_INSTALL_DIR}"
chmod u+x "${ACME_SCRIPT_INSTALL_DIR}/acme.sh"
if [ -x "${ACME_SCRIPT_INSTALL_DIR}/acme.sh" ]; then
    print_success "Acme.sh installed in ${ACME_SCRIPT_INSTALL_DIR}"
else
    print_error "Acme.sh in ${ACME_SCRIPT_INSTALL_DIR} is not executable.... aborting"
    exit 1
fi

# Gather user inputs for configuration
echo "\n⏳ Provide required DSM and CloudFlare data so we can create a configuration file for you \n"

read -p "Domain name you want to use with your Synology NAS: " SYNOLOGY_DOMAIN_NAME
read -p "E-mail address (required by ZeroSSL ${ZEROSSL_HELP_URL}): " ZEROSSL_EMAIL
read -p "Dedicated administrator user on NAS (required to be in groups http and administrators ‼️): " SYNOLOGY_NAS_USER
read -s -p "Password for user ${USER} to your NAS: " SYNOLOGY_NAS_PASSWORD
printf "\n"
read -p "Http port of your DSM (leave empty for default 5000): " SYNOLOGY_NAS_DSM_HTTP_PORT
read -p "Your CloudFlare's API token: " CERTIFICATE_CLOUDFLARE_TOKEN
read -p "Your CloudFlare's domain zone identifier: " CERTIFICATE_CLOUDFLARE_ZONE_ID
read -p "Your CloudFlare's account ID: " CERTIFICATE_CLOUDFLARE_TOKEN_ACCOUNT_ID

if [ -z ${SYNOLOGY_NAS_DSM_HTTP_PORT} ]; then
    SYNOLOGY_NAS_DSM_HTTP_PORT=5000
fi

if [ -z "$SYNOLOGY_DOMAIN_NAME" ] || \
   [ -z "$ZEROSSL_EMAIL" ] || \
   [ -z "$SYNOLOGY_NAS_PASSWORD" ] || \
   [ -z "$SYNOLOGY_NAS_USER" ] || \
   [ -z "$CERTIFICATE_CLOUDFLARE_TOKEN" ] || \
   [ -z "$CERTIFICATE_CLOUDFLARE_ZONE_ID" ] || \
   [ -z "$CERTIFICATE_CLOUDFLARE_TOKEN_ACCOUNT_ID" ]; then
    print_error "You need to provide all required inputs to create the configuration file automatically."
    exit 1
fi

cat << EOF > ${ACME_SCRIPT_INSTALL_DIR}/${CERTIFICATE_CONFIG_FILE}
# Synology DSM configuration
export SYNO_USERNAME="${SYNOLOGY_NAS_USER}"
export SYNO_PASSWORD="${SYNOLOGY_NAS_PASSWORD}"
export SYNO_CERTIFICATE="ZeroSSL free"
export SYNO_CREATE=1
export SYNO_HOSTNAME="localhost"
export SYNO_PORT="${SYNOLOGY_NAS_DSM_HTTP_PORT}"
export SYNO_SCHEME="http"

# CloudFlare configuration
export CF_Token="${CERTIFICATE_CLOUDFLARE_TOKEN}"
export CF_Zone_ID="${CERTIFICATE_CLOUDFLARE_ZONE_ID}"
export CF_Account_ID="${CERTIFICATE_CLOUDFLARE_TOKEN_ACCOUNT_ID}"

# ZeroSSL configuration
export ZEROSSL_EMAIL="${ZEROSSL_EMAIL}"
export SYNOLOGY_DOMAIN_NAME="${SYNOLOGY_DOMAIN_NAME}"
EOF

print_success "Configuration file has been created for you in ${ACME_SCRIPT_INSTALL_DIR}/${CERTIFICATE_CONFIG_FILE}."

cat << 'EOF' > "${ACME_SCRIPT_INSTALL_DIR}/generate-certificate.bash"
#!/bin/bash

if [[ $EUID -eq 0 ]]; then
    echo "Error: This script should NOT be run as root (or with sudo)." >&2
    echo "Run it as a ${SYNO_USERNAME} user instead." >&2
    exit 1
fi

SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
source "${SCRIPT_DIR}/account.conf"
ACME_SH="${SCRIPT_DIR}/acme.sh"

if [[ ! -x "${ACME_SH}" ]]; then
    echo "Error: Cannot execute ${ACME_SH}" >&2
    exit 1
fi

# Register account in ZeroSSL
"${ACME_SH}" --register-account -m "${ZEROSSL_EMAIL}"

# Generate ZeroSSL certificate
"${ACME_SH}" --issue --dns dns_cf -d "${SYNOLOGY_DOMAIN_NAME}"

# Install ZeroSSL certificate
"${ACME_SH}" -d "${SYNOLOGY_DOMAIN_NAME}" --deploy --deploy-hook synology_dsm 
EOF
chmod u+x "${ACME_SCRIPT_INSTALL_DIR}/generate-certificate.bash"

cat << 'EOF' > "${ACME_SCRIPT_INSTALL_DIR}/renew-certificate.bash"
#!/bin/bash

if [[ $EUID -eq 0 ]]; then
    echo "Error: This script should NOT be run as root (or with sudo)." >&2
    echo "Run it as a ${SYNOLOGY_NAS_USER} user instead." >&2
    exit 1
fi

SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
source "${SCRIPT_DIR}/account.conf"
ACME_SH="${SCRIPT_DIR}/acme.sh"

if [[ ! -x "${ACME_SH}" ]]; then
    echo "Error: Cannot execute ${ACME_SH}" >&2
    exit 1
fi

# Renew certificate
"${ACME_SH}" --renew -d "${SYNOLOGY_DOMAIN_NAME}"
EOF
chmod u+x "${ACME_SCRIPT_INSTALL_DIR}/renew-certificate.bash"
chown -R "${SYNOLOGY_NAS_USER}" "${ACME_SCRIPT_INSTALL_DIR}"

print_success "Certificate generation and renewal script have been created in ${ACME_SCRIPT_INSTALL_DIR}"
echo "\nAll done here 🎉. Go to ${ACME_SCRIPT_INSTALL_DIR} and run ./generate-certificate.bash\n"
