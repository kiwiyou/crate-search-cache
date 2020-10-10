#!/bin/sh

wget 'https://static.crates.io/db-dump.tar.gz'
db_dir="$(tar tf db-dump.tar.gz | head -1)"
tar xf db-dump.tar.gz
rm db-dump.tar.gz
cd "$db_dir"
PGPASSWORD=$DATABASE_PASSWORD psql -U "$DATABASE_USER" -h "$DATABASE_HOST" -f import.sql
cd ../
rm -rf "$db_dir"