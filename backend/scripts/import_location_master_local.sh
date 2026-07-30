#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
DATA_DIR="${LOCATION_DATA_DIR:-${BACKEND_ROOT}/data/location-master}"

GEOLONIA_URL="${GEOLONIA_LATEST_CSV_URL:-https://raw.githubusercontent.com/geolonia/japanese-addresses/master/data/latest.csv}"
GEOLONIA_CSV="${GEOLONIA_CSV:-${DATA_DIR}/geolonia/latest.csv}"
EKIDATA_STATION_CSV="${EKIDATA_STATION_CSV:-${DATA_DIR}/ekidata/station.csv}"
EKIDATA_LINE_CSV="${EKIDATA_LINE_CSV:-${DATA_DIR}/ekidata/line.csv}"
RUNNER="${LOCATION_IMPORT_RUNNER:-docker}"
REFRESH_GEOLONIA="${REFRESH_GEOLONIA:-0}"

mkdir -p "$(dirname "${GEOLONIA_CSV}")" "$(dirname "${EKIDATA_STATION_CSV}")"

if [[ ! -f "${GEOLONIA_CSV}" || "${REFRESH_GEOLONIA}" == "1" ]]; then
  echo "Downloading Geolonia latest.csv to ${GEOLONIA_CSV}"
  curl -fL "${GEOLONIA_URL}" -o "${GEOLONIA_CSV}"
else
  echo "Using existing Geolonia CSV: ${GEOLONIA_CSV}"
fi

if [[ ! -f "${EKIDATA_STATION_CSV}" ]]; then
  cat >&2 <<EOF
Missing station CSV: ${EKIDATA_STATION_CSV}

Download station.csv from ekidata.jp, then place it at:
  ${EKIDATA_STATION_CSV}

Optional line master:
  ${EKIDATA_LINE_CSV}

The station CSV is not downloaded automatically because ekidata.jp data may
require registration or paid access, especially when kana columns are needed.
EOF
  exit 1
fi

IMPORT_ARGS=(
  "--municipalities-csv"
  "${GEOLONIA_CSV}"
  "--stations-csv"
  "${EKIDATA_STATION_CSV}"
)

if [[ -f "${EKIDATA_LINE_CSV}" ]]; then
  IMPORT_ARGS+=("--station-lines-csv" "${EKIDATA_LINE_CSV}")
else
  echo "Warning: line CSV not found. Importing stations without line names: ${EKIDATA_LINE_CSV}" >&2
fi

cd "${BACKEND_ROOT}"

if [[ "${RUNNER}" == "host" ]]; then
  python scripts/import_locations.py "${IMPORT_ARGS[@]}"
else
  if ! docker compose ps api --status running >/dev/null 2>&1; then
    cat >&2 <<EOF
The backend api container is not running.

Start local backend first:
  cd ${BACKEND_ROOT}
  docker compose up -d --build

Then rerun:
  ./scripts/import_location_master_local.sh
EOF
    exit 1
  fi

  CONTAINER_ARGS=()
  for value in "${IMPORT_ARGS[@]}"; do
    if [[ "${value}" == "${BACKEND_ROOT}"* ]]; then
      CONTAINER_ARGS+=("/app${value#"${BACKEND_ROOT}"}")
    else
      CONTAINER_ARGS+=("${value}")
    fi
  done

  docker compose exec -T api python scripts/import_locations.py "${CONTAINER_ARGS[@]}"
fi
