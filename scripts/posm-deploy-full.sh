#!/usr/bin/env bash

hot_export_url=$1

# Fetch HOT Export
uuid=$(uuidgen)
tmp_dir=/opt/admin/tmp/$uuid
./hot-export-fetch.sh $hot_export_url $tmp_dir

# Move deployment from temp to deployment dir
manifest_path=$tmp_dir/manifest.json
deployment_name=$(cat $manifest_path | jq -r '.name')
deployment_dir=/opt/data/deployments/$deployment_name
echo "==> posm-deploy-full.sh"
echo "      deployment name: "$deployment_name
echo
./hot-export-move.sh $tmp_dir $deployment_dir

# Convert XLS to XForm
omk_dir=/opt/omk/OpenMapKitServer
pyxform=$omk_dir/api/odk/pyxform/pyxform/xls2xform.py
omk_forms_dir=$omk_dir/data/forms
./xls2xform.sh $pyxform $deployment_dir $omk_forms_dir

# Drop and create API DB
scripts_dir=/opt/admin/posm-admin/scripts/
sudo -u postgres $scripts_dir/postgres_api-db-drop-create.sh

# Init API DB
sudo -u osm $scripts_dir/osm_api-db-init.sh

# Populate API DB
sudo -u osm $scripts_dir/osm_api-db-populate.sh $deployment_dir

# Dump API DB to a PBF (Osmosis)
sudo -u osm $scripts_dir/render-db-api2pbf.sh

# Reset and populate Render DB with latest PBF dump (osm2pgsql)
sudo -u gis $scripts_dir/render-db-pbf2render.sh

# Reset configs for tessera and field papers. Reset services.
manifest_path=$deployment_dir/manifest.json
./tessera-fp-reset.js $manifest_path

# Create OSM XML layers for OpenMapKit
./omk-osm.sh $deployment_dir

# Create POSM MBTiles for OpenMapKit
sudo -u gis $scripts_dir/omk-mbtiles.sh $deployment_dir
