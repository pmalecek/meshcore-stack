# MeshCore stack

Instalace [meshcore-server](https://github.com/pmalecek/meshcore-server) a [meshcore-klient](https://github.com/pmalecek/meshcore-klient)
v Dockeru jedním příkazem. Server drží spojení s MeshCore companionem (WiFi, USB nebo Bluetooth), klient je
webové rozhraní, které se k serveru samo připojí. Databáze (MariaDB), PHP i Python běží v kontejnerech,
na počítači stačí Docker.

## Instalace

Na Linuxu (PC, server, Raspberry Pi, kontejner v Proxmoxu) spusť v terminálu nebo přes SSH:

```bash
curl -fsSL https://raw.githubusercontent.com/pmalecek/meshcore-stack/main/install.sh | bash
```

Instalátor:

1. zkontroluje Docker (když chybí, nabídne jeho instalaci),
2. zeptá se, jak je připojený companion (WiFi a jeho IP adresa, USB, nebo Bluetooth) a na port webu,
3. stáhne klienta a server a sestaví je (poprvé pár minut, na Raspberry Pi i 15 minut),
4. spustí databázi, server a klienta a propojí je,
5. vytvoří uživatele webu a vypíše adresu, jméno a **heslo – ulož si ho, znovu se nezobrazí**.

Pak otevři v prohlížeči vypsanou adresu, např. `http://192.168.1.50:8080/`.

Instaluje se do `~/meshcore-stack` (jinou složku nastavíš proměnnou `MESHCORE_DIR`).

**Windows:** návod v [docs/windows.md](docs/windows.md). **USB:** [docs/usb.md](docs/usb.md). **Bluetooth:** [docs/ble.md](docs/ble.md).

## Aktualizace

Spusť instalační příkaz znovu. Stáhne a sestaví nové verze, data, nastavení i uživatelé zůstanou. Na nic se neptá.
Verze klienta a serveru jsou v `.env` (`KLIENT_REF`, `SERVER_REF`); nový instalátor může přinést novější výchozí.

Změna připojení companionu (např. jiná IP adresa):

```bash
cd ~/meshcore-stack
nano .env                  # COMPANION_HOST=…
docker compose up -d
```

nebo instalátor s `RECONFIGURE=1`, který se znovu zeptá:

```bash
curl -fsSL https://raw.githubusercontent.com/pmalecek/meshcore-stack/main/install.sh | RECONFIGURE=1 bash
```

## Běžné příkazy

Ve složce `~/meshcore-stack`:

```bash
docker compose ps                                  # stav kontejnerů
docker compose logs -f meshcore-server             # log serveru (spojení s companionem)
docker compose logs -f klient-worker               # log klienta
docker compose restart                             # restart všeho
docker compose down                                # zastavení (data zůstanou)
docker compose exec klient-web php bin/user.php add petr --password=TajneHeslo123   # další uživatel
docker compose exec klient-web php bin/user.php list
docker compose exec -it klient-web php bin/user.php reset admin   # přihlašování kódem (TOTP), vypíše klíč pro aplikaci
```

## Co běží

| Kontejner | Úkol |
|---|---|
| `db` | MariaDB 11.8, databáze `meshcore_server` a `meshcore_klient` |
| `meshcore-server` | spojení s companionem, API (jen uvnitř Dockeru) |
| `klient-web` | webové rozhraní (port `WEB_PORT`, výchozí 8080) |
| `klient-worker` | napojení klienta na server (živé zprávy) |
| `klient-heard` | kontrola heard přes analyzer, úklid historie |

Data jsou v Docker svazcích `db-data`, `server-data` a `klient-data` a přežijí aktualizace i restart.
Nastavení včetně vygenerovaných hesel a API tokenu je v `.env` (čitelný jen pro vlastníka).

API serveru zpřístupníš pro další klienty odkomentováním `ports` u `meshcore-server` v `docker-compose.yml`.

## Záloha

```bash
cd ~/meshcore-stack
docker compose exec db sh -c 'mariadb-dump -uroot -p"$MARIADB_ROOT_PASSWORD" --single-transaction --databases meshcore_server meshcore_klient' > zaloha.sql
cp .env zaloha.env
```

## Poznámky

- Web běží přes **HTTP**. To stačí v domácí síti. Bluetooth režim klienta (`/ble`), instalace jako aplikace
  a notifikace v prohlížeči potřebují HTTPS – postav před stack reverse proxy s certifikátem (Caddy, Nginx Proxy
  Manager, Traefik).
- Na internet web bez HTTPS a dalšího zabezpečení nevystavuj.
- Odinstalace: `docker compose down -v` ve složce stacku (smaže i data!) a pak smaž složku.

## Licence

MIT, viz [LICENSE](LICENSE).
