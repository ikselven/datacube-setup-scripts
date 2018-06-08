#!/bin/bash

declare -r SCRIPTDIR="$(readlink -f "$(dirname "$0")")"
source "$SCRIPTDIR/util.sh"

_activate

echo "[DATACUBE-INGEST] Ingesting sample data..."

echo "[DATACUBE-INGEST] Adding new product definition to datacube..."
datacube product add "$DCUBE_HOME/agdc-v2/ingest/dataset_types/ls8_collections_sr_scene.yaml"

echo "[DATACUBE-INGEST] Preparing data for ingestion..."
python "$DCUBE_HOME/agdc-v2/ingest/prepare_scripts/usgs_ls_ard_prepare.py" "$DCUBE_HOME"/data/original_data/LC08*

echo "[DATACUBE-INGEST] Adding dataset metadata to datacube..."
datacube dataset add "$DCUBE_HOME"/data/original_data/LC08*/*.yaml --auto-match

echo "[DATACUBE-INGEST] Ingesting data..."
datacube -v ingest \
    -c "$DCUBE_HOME/agdc-v2/ingest/ingestion_configs/ls8_collections_sr_fuente_de_piedra_example.yaml"  \
    --executor multiproc 2

_deactivate

echo "[DATACUBE-INGEST] Data ingestion finished."
