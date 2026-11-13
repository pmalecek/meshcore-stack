# MeshCore stack

Instalace [meshcore-server](https://github.com/pmalecek/meshcore-server) a [meshcore-klient](https://github.com/pmalecek/meshcore-klient)
v Dockeru jedním příkazem. Server drží spojení s MeshCore companionem (WiFi, USB nebo Bluetooth), klient je
webové rozhraní, které se k serveru samo připojí. Databáze (MariaDB), PHP i Python běží v kontejnerech,
na počítači stačí Docker.

## Instalace

Na Linuxu (PC, server, Raspberry Pi, kontejner v Proxmoxu) spusť v terminálu nebo přes SSH:

```bash
curl -fsSL "https://raw.githubusercontent.com/pmalecek/meshcore-stack/main/install.sh?$(date +%s)" | bash
```

Instalátor:

1. zkontroluje Docker,
2. stáhne stack do `~/meshcore-stack` a zpřístupní příkaz `meshcore-stack`,
3. zeptá se, jak je připojený companion (WiFi a jeho IP adresa, USB, nebo Bluetooth) a na port webu,
4. stáhne klienta a server a sestaví je (poprvé pár minut, na Raspberry Pi i 15 minut),
5. spustí databázi, server a klienta a propojí je,
6. vytvoří uživatele webu a vypíše adresu, jméno a **heslo – ulož si ho, znovu se nezobrazí**.

Pak otevři v prohlížeči vypsanou adresu, např. `http://192.168.1.50:8080/`.

Jinou složku nastavíš proměnnou `MESHCORE_DIR`. Dialogy v terminálu používají `whiptail`
(`sudo apt install whiptail`), bez něj se instalátor ptá obyčejným textem.

**Windows:** návod v [docs/windows.md](docs/windows.md). **USB:** [docs/usb.md](docs/usb.md). **Bluetooth:** [docs/ble.md](docs/ble.md).

## Správa: příkaz `meshcore-stack`

Bez parametrů otevře menu:

| Položka | Co dělá |
|---|---|
| Stav | verze, spojení se serverem a companionem, velikost databází, zálohy, kontejnery |
| Aktualizace | stáhne nový stack, ukáže změnu verzí, **zazálohuje** a sestaví nové verze |
| Připojení companionu | změna WiFi / USB / Bluetooth, IP adresy, portu |
| Uživatelé webu | seznam, přidání, nové heslo, přihlašování kódem (TOTP, s QR kódem, je-li `qrencode`), smazání |
| Záloha / Obnova | záloha do `~/meshcore-stack/backups` (ponechají se poslední 3), obnova vybrané zálohy |
| Logy | výpis logu vybraného kontejneru |
| Spustit / zastavit / restart | |
| API serveru | zpřístupnění API meshcore-serveru dalším aplikacím na zvoleném portu, vytvoření tokenu |
| Odinstalace | nejdřív záloha (přesune se do `~/meshcore-stack-zalohy`), pak smaže kontejnery, data i složku |

Totéž z příkazové řádky (i pro cron):

```bash
meshcore-stack status
meshcore-stack update                 # YES=1 meshcore-stack update = bez potvrzení
meshcore-stack backup
meshcore-stack restore ~/meshcore-stack/backups/meshcore-20261113-0300.tar.gz
meshcore-stack user add petr          # vygeneruje heslo; user passwd|delete|list|totp
meshcore-stack api on 8081            # api off
meshcore-stack token home-assistant   # token pro další aplikaci (read/write/admin, výchozí write)
meshcore-stack logs meshcore-server
meshcore-stack start | stop | restart
meshcore-stack help
```

Noční záloha přes cron (`crontab -e`):

```
0 3 * * * /usr/local/bin/meshcore-stack backup >/dev/null 2>&1
```

Záloha obsahuje obě databáze, `.env` (včetně hesel a tokenu – soubor je čitelný jen pro vlastníka)
a data klienta (vlastní pozadí). Pro jistotu si ji občas zkopíruj mimo počítač.

## Verze

`KLIENT_REF` a `SERVER_REF` v `.env` jsou ve výchozím stavu `auto` – použije se verze, kterou určuje
aktuální stack, takže stačí `meshcore-stack update`. Pro konkrétní verzi nastav tag nebo větev
(např. `KLIENT_REF=v1.0.4` nebo `KLIENT_REF=main`) a spusť aktualizaci; zpět na `auto` stejně.

Instalace z dřívějšího `install.sh` se při první aktualizaci přepnou na `auto` a ručně přidaný
`compose.api.yml` nahradí volba *API serveru* (port zůstane 8081).

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

Ve složce stacku funguje i přímo `docker compose …` (soubory vybírá `COMPOSE_FILE` v `.env`).

## Poznámky

- Web běží přes **HTTP**. To stačí v domácí síti. Bluetooth režim klienta (`/ble`), instalace jako aplikace
  a notifikace v prohlížeči potřebují HTTPS – postav před stack reverse proxy s certifikátem (Caddy, Nginx Proxy
  Manager, Traefik).
- Na internet web bez HTTPS a dalšího zabezpečení nevystavuj.

## Licence

MIT, viz [LICENSE](LICENSE).
