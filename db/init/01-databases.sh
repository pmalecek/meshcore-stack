#!/bin/sh
# Spustí se jen při prvním startu MariaDB (prázdný svazek db-data).
# Založí databáze a uživatele pro klienta a server.
set -e
mariadb -uroot -p"$MARIADB_ROOT_PASSWORD" <<SQL
CREATE DATABASE IF NOT EXISTS meshcore_klient CHARACTER SET utf8mb4 COLLATE utf8mb4_uca1400_ai_ci;
CREATE DATABASE IF NOT EXISTS meshcore_server CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS 'meshcore_klient'@'%' IDENTIFIED BY '${KLIENT_DB_PASSWORD}';
CREATE USER IF NOT EXISTS 'meshcore_server'@'%' IDENTIFIED BY '${SERVER_DB_PASSWORD}';
GRANT ALL ON meshcore_klient.* TO 'meshcore_klient'@'%';
GRANT ALL ON meshcore_server.* TO 'meshcore_server'@'%';
FLUSH PRIVILEGES;
SQL
