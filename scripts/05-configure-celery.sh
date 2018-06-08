#!/bin/bash

set -e

declare -r SCRIPTDIR="$(readlink -f "$(dirname "$0")")"
source "$SCRIPTDIR/util.sh"

_activate
declare -r celery_bin="$(which celery)"
_deactivate

echo "[DC_CELERY-SETUP] Installing celery service..."
sudo install -vDm644 "${CONFDIR}/celery.service" /etc/systemd/system/celery.service
sed --regexp-extended --in-place 's,(CELERY_BIN=").*",\1'"$celery_bin"'",' "${CONFDIR}/celery"
sudo install -vDm644 "${CONFDIR}/celery" /etc/conf.d/celery

echo "[DC_CELERY-SETUP] Installing celery-beat service..."
sudo install -vDm644 "${CONFDIR}/celery-beat.service" /etc/systemd/system/celery-beat.service
sed --regexp-extended --in-place 's,(CELERY_BIN=").*",\1'"$celery_bin"'",' "${CONFDIR}/celery-beat"
sudo install -vDm644 "${CONFDIR}/celery-beat" /etc/conf.d/celery-beat

echo "[DC_CELERY-SETUP] Installing tmpfiles.d configuration for celery and celery-beat..."
sudo install -vDm644 "${CONFDIR}/celery.conf" /etc/tmpfiles.d/celery.conf
sudo systemd-tmpfiles --create

echo "[DC_CELERY-SETUP] Reloading systemd configuration..."
sudo systemctl daemon-reload

echo "[DC_CELERY-SETUP] Raising celery and celery-beat services..."
sudo systemctl start celery
sudo systemctl start celery-beat

echo "[DC_CELERY-SETUP] Finished celery setup."
