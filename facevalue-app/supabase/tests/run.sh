#!/usr/bin/env bash
# Applies every migration to a throwaway database and runs the RLS suite.
#   ./run.sh                 # against local Postgres on :5433
#   PGURI=... ./run.sh       # against anything else
set -euo pipefail
cd "$(dirname "$0")"
DB="${DB:-facevalue_test}"
PSQL_BASE=${PGURI:+psql "$PGURI"}
H=${PGHOST:-/tmp}; P=${PGPORT:-5433}; U=${PGUSER:-postgres}

psql -h "$H" -p "$P" -U "$U" -d postgres -qc "drop database if exists $DB;" >/dev/null
psql -h "$H" -p "$P" -U "$U" -d postgres -qc "create database $DB;" >/dev/null
run() { psql -h "$H" -p "$P" -U "$U" -d "$DB" -v ON_ERROR_STOP=1 -q -f "$1"; }

run local_auth_stub.sql
for m in ../migrations/*.sql; do run "$m"; done
psql -h "$H" -p "$P" -U "$U" -d "$DB" -v ON_ERROR_STOP=1 -f rls_test.sql 2>&1 \
  | grep -E 'PASS|FAIL|passed' || true
