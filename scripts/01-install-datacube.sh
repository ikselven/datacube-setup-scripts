#!/bin/bash

set -e

declare -r SCRIPTDIR="$(readlink -f "$(dirname "$0")")"
source "$SCRIPTDIR/util.sh"

echo "[DATACUBE-SETUP] Setting up conda and creating environment..."

conda config --add channels conda-forge
conda create --yes --name "$CUBEENV" python=3.6

conda install --name "$CUBEENV" --yes datacube jupyter matplotlib scipy

echo "[DATACUBE-SETUP] Installing postgresql..."

sudo apt install --assume-yes postgresql-9.6 postgresql-client-9.6 postgresql-contrib-9.6

echo "[DATACUBE-SETUP] Configuring postgresql..."
sudo systemctl stop postgres.service

sudo _backup /etc/postgresql/9.6/main/pg_hba.conf
# configuring tcp socket access for developer
if ! sudo grep -E "^host\s+all\s+developer\s+samenet\s+trust$" /etc/postgresql/9.6/main/pg_hba.conf > /dev/null; then
    echo "host    all             developer       samenet                 trust" \
        | sudo tee --append /etc/postgresql/9.6/main/pg_hba.conf
fi

sudo _backup /etc/postgresql/9.6/main/postgresql.conf
sudo install -vDm644 "${CONFDIR}/postgresql.conf" /etc/postgresql/9.6/main/postgresql.conf

sudo systemctl start postgres.service

echo "[DATACUBE-SETUP] Setting up postgresql database and users..."
declare DB_USER="$USER"
declare DB_PASSWD="developer"
sudo --user=postgres createuser --host=localhost --superuser "$DB_USER"
# create database for the newly created user
createdb
sudo --user=postgres psql --command="ALTER $DB_USER developer WITH PASSWORD '$DB_PASSWD';"
createdb datacube

echo "[DATABASE-SETUP] Configuring database access for datacube..."
cat > "$HOME/.datacube.conf" <<CONFIG
[datacube]
db_database: datacube
db_hostname: localhost
db_username: $DB_USER
db_password: $DB_PASSWD
CONFIG

unset PASSWORD

echo "[DATABASE-SETUP] Initializing datacube..."
_activate
datacube -v system init
_deactivate

echo "[DATACUBE-SETUP] Setup finished."
