#!/bin/bash

set -e

declare -r SCRIPTDIR="$(readlink -f "$(dirname "$0")")"
source "$SCRIPTDIR/util.sh"

echo "[DATACUBE-SETUP] Installing additional packages for data import into conda environment..."

declare -ra PYTHON_PACKAGES=(
"numpy"
"pathlib"
"pyyaml"
"python-dateutil"
"rasterio"
"shapely"
"cachetools"
)

conda install --name "$CUBEENV" --yes "${PYTHON_PACKAGES[@]}"

echo "[DATACUBE-SETUP] Installed additional packages for import."

echo "[DATACUBE-SETUP] Creating datacube data directories..."

mkdir -vp "$DATA_HOME"
mkdir -vp "$DATA_HOME/ingested_data"
mkdir -vp "$DATA_HOME/original_data"
declare -r UIDIR="$DATA_HOME/ui_results"
mkdir -vp "$UIDIR"
mkdir -vp "${UIDIR}_temp"
mkdir -vp "$UIDIR/custom_mosaic"
mkdir -vp "$UIDIR/fractional_cover"
mkdir -vp "$UIDIR/tsm"
mkdir -vp "$UIDIR/water_detection"
mkdir -vp "$UIDIR/slip"

chmod --recursive 775 "$DATA_HOME"

echo "[DATACUBE-SETUP] Created datacube data directories."
