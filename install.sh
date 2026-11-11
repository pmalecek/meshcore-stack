#!/usr/bin/env bash
# MeshCore stack – instalace a aktualizace meshcore-serveru a meshcore-klienta v Dockeru.
#
#   curl -fsSL https://raw.githubusercontent.com/pmalecek/meshcore-stack/main/install.sh | bash
#
# Při prvním spuštění se zeptá, jak je připojený companion, vše stáhne, sestaví a spustí
# a na konci vypíše adresu a přihlašovací údaje. Další spuštění = aktualizace (nic se neptá).
#
# Proměnné prostředí (nepovinné):
#   MESHCORE_DIR       kam instalovat (výchozí ~/meshcore-stack)
#   STACK_REF          verze tohoto repozitáře (výchozí main)
#   RECONFIGURE=1      znovu se zeptat na připojení companionu (při aktualizaci)
#   Neinteraktivní instalace: COMPANION_TRANSPORT=tcp|usb|ble a COMPANION_HOST / COMPANION_DEVICE /
#   COMPANION_BLE_ADDRESS, volitelně WEB_PORT, TZ, ADMIN_USER.
set -euo pipefail

# Vše je ve funkci main (volá se na konci), aby bash při „curl … | bash“ načetl celý skript
# dřív, než cokoli spustí – jinak by příkazy čtoucí stdin (docker exec) spolkly zbytek skriptu.
main() {

GITHUB="${MESHCORE_GITHUB:-https://github.com/pmalecek}"
STACK_REF="${STACK_REF:-main}"
DIR="${MESHCORE_DIR:-$HOME/meshcore-stack}"

# výchozí verze klienta a serveru (lze přepsat v .env: KLIENT_REF, SERVER_REF)
DEFAULT_KLIENT_REF="v1.0.0"
DEFAULT_SERVER_REF="v0.11.0"

c_ok=$'\e[32m'; c_warn=$'\e[33m'; c_err=$'\e[31m'; c_b=$'\e[1m'; c_0=$'\e[0m'
[ -t 1 ] || { c_ok=; c_warn=; c_err=; c_b=; c_0=; }
info() { echo "${c_b}==>${c_0} $*"; }
ok()   { echo "${c_ok}✔${c_0} $*"; }
warn() { echo "${c_warn}!${c_0} $*" >&2; }
die()  { echo "${c_err}✘ $*${c_0}" >&2; exit 1; }

# dotaz i při „curl … | bash“ (stdin je roura) – čte se z terminálu
TTY=/dev/tty
ask() { # ask "Otázka" "výchozí" -> REPLY
    local q="$1" def="${2:-}"
    if [ ! -r "$TTY" ]; then REPLY="$def"; return; fi
    if [ -n "$def" ]; then printf '%s [%s]: ' "$q" "$def" > "$TTY"; else printf '%s: ' "$q" > "$TTY"; fi
    IFS= read -r REPLY < "$TTY" || REPLY=""
    REPLY="${REPLY:-$def}"
}

gen_pw() { # náhodné heslo jen z písmen a číslic (bez uvozovek a speciálních znaků)
    LC_ALL=C tr -dc 'A-Za-z0-9' < /dev/urandom | head -c "${1:-24}" || true
}

env_get() { # env_get KLÍČ -> hodnota z .env
    [ -f "$DIR/.env" ] || return 0
    grep -E "^$1=" "$DIR/.env" | tail -1 | cut -d= -f2- || true
}

env_set() { # env_set KLÍČ HODNOTA – nastaví nebo přidá řádek v .env
    local k="$1" v="$2"
    if grep -qE "^$k=" "$DIR/.env" 2>/dev/null; then
        local tmp; tmp="$(mktemp)"
        awk -v k="$k" -v v="$v" -F= 'BEGIN{OFS="="} $1==k {print k, v; next} {print}' "$DIR/.env" > "$tmp"
        cat "$tmp" > "$DIR/.env"; rm -f "$tmp"
    else
        echo "$k=$v" >> "$DIR/.env"
    fi
}

download() { # download REPO REF CÍL – stáhne zdrojáky jako archiv (git není potřeba)
    local repo="$1" ref="$2" dest="$3" tmp
    tmp="$(mktemp -d)"
    info "Stahuji $repo ($ref)"
    if ! curl -fsSL "$GITHUB/$repo/archive/$ref.tar.gz" -o "$tmp/src.tar.gz"; then
        rm -rf "$tmp"
        die "Nepodařilo se stáhnout $repo verze $ref. Existuje na GitHubu (tag nebo větev)?"
    fi
    rm -rf "$dest"; mkdir -p "$dest"
    tar -xzf "$tmp/src.tar.gz" -C "$dest" --strip-components=1
    rm -rf "$tmp"
}

# ---------------------------------------------------------------- kontroly

[ "$(uname -s)" = "Linux" ] || warn "Instalátor je pro Linux (na Windows použij WSL, viz docs/windows.md)."
command -v curl >/dev/null || die "Chybí curl (apt install curl)."
command -v tar  >/dev/null || die "Chybí tar."

if ! command -v docker >/dev/null; then
    warn "Docker není nainstalovaný."
    ask "Nainstalovat Docker oficiálním skriptem get.docker.com? (a/n)" "a"
    case "$REPLY" in
        a|A|y|Y|ano)
            curl -fsSL https://get.docker.com | sh
            if [ "$(id -u)" -ne 0 ]; then
                sudo usermod -aG docker "$USER" || true
                warn "Přidal jsem tě do skupiny docker. Odhlas se a přihlas znovu (nebo spusť 'newgrp docker') a spusť instalaci ještě jednou."
                exit 0
            fi ;;
        *) die "Bez Dockeru to nepůjde. Návod: https://docs.docker.com/engine/install/" ;;
    esac
fi

DOCKER=(docker)
if ! docker info >/dev/null 2>&1; then
    if [ "$(id -u)" -ne 0 ] && sudo -n docker info >/dev/null 2>&1; then
        DOCKER=(sudo docker)
    elif [ "$(id -u)" -ne 0 ] && command -v sudo >/dev/null; then
        warn "Docker vyžaduje sudo (nebo členství ve skupině docker)."
        DOCKER=(sudo docker)
        sudo docker info >/dev/null || die "Docker neběží (sudo systemctl start docker)."
    else
        die "Docker neběží nebo k němu nemáš přístup (sudo systemctl start docker)."
    fi
fi
"${DOCKER[@]}" compose version >/dev/null 2>&1 || die "Chybí Docker Compose v2 (balíček docker-compose-plugin)."
dc() { (cd "$DIR" && "${DOCKER[@]}" compose "$@") < /dev/null; }

# ---------------------------------------------------------------- soubory stacku

mkdir -p "$DIR"
FIRST=0
[ -f "$DIR/.env" ] || FIRST=1

download meshcore-stack "$STACK_REF" "$DIR/.stack-new"
# aktualizovat soubory stacku, ale nesahat na .env a data
(cd "$DIR/.stack-new" && tar -cf - --exclude=./.env --exclude=./src .) | (cd "$DIR" && tar -xf -)
rm -rf "$DIR/.stack-new"
chmod +x "$DIR/install.sh" "$DIR/db/init/"*.sh 2>/dev/null || true

# ---------------------------------------------------------------- konfigurace

configure_companion() {
    local t="${COMPANION_TRANSPORT:-}"
    if [ -z "$t" ]; then
        echo > "$TTY" 2>/dev/null || true
        echo "Jak je připojený MeshCore companion?" > "${TTY}" 2>/dev/null || true
        echo "  1) WiFi (TCP) – companion s WiFi firmwarem v síti (doporučeno)" > "$TTY" 2>/dev/null || true
        echo "  2) USB kabelem k tomuto počítači" > "$TTY" 2>/dev/null || true
        echo "  3) Bluetooth (pokročilé, viz docs/ble.md)" > "$TTY" 2>/dev/null || true
        ask "Volba" "1"
        case "$REPLY" in 2) t=usb ;; 3) t=ble ;; *) t=tcp ;; esac
    fi
    env_set COMPANION_TRANSPORT "$t"
    env_set COMPOSE_FILE "docker-compose.yml:compose.$t.yml"
    case "$t" in
        tcp)
            local host="${COMPANION_HOST:-$(env_get COMPANION_HOST)}" port="${COMPANION_PORT:-$(env_get COMPANION_PORT)}"
            [ -n "${COMPANION_HOST:-}" ] || { ask "IP adresa companionu" "$host"; host="$REPLY"; }
            [ -n "$host" ] || die "IP adresa companionu je povinná."
            [ -n "${COMPANION_PORT:-}" ] || { ask "TCP port companionu" "${port:-5000}"; port="$REPLY"; }
            env_set COMPANION_HOST "$host"; env_set COMPANION_PORT "${port:-5000}" ;;
        usb)
            local dev="${COMPANION_DEVICE:-}" found
            found="$(ls /dev/serial/by-id/* /dev/ttyACM* /dev/ttyUSB* 2>/dev/null | head -1 || true)"
            [ -n "$dev" ] || { ask "Sériový port companionu" "${found:-/dev/ttyUSB0}"; dev="$REPLY"; }
            [ -e "$dev" ] || warn "Zařízení $dev teď neexistuje – zkontroluj, že je companion připojený."
            env_set COMPANION_DEVICE "$dev"
            env_set COMPANION_DEVICE_GID "$(stat -Lc %g "$dev" 2>/dev/null || echo 20)" ;;
        ble)
            local mac="${COMPANION_BLE_ADDRESS:-}" pin="${COMPANION_BLE_PIN:-}"
            [ -n "$mac" ] || { ask "MAC adresa companionu (prázdné = vyhledat)" ""; mac="$REPLY"; }
            [ -n "$pin" ] || { ask "PIN pro spárování (prázdné = bez PINu)" ""; pin="$REPLY"; }
            env_set COMPANION_BLE_ADDRESS "$mac"; env_set COMPANION_BLE_PIN "$pin"
            warn "Bluetooth v Dockeru vyžaduje BlueZ na hostiteli – projdi docs/ble.md." ;;
    esac
}

if [ "$FIRST" = 1 ]; then
    info "První instalace do $DIR"
    : > "$DIR/.env"
    chmod 600 "$DIR/.env"
    {
        echo "# MeshCore stack – nastavení (vytvořil install.sh $(date '+%Y-%m-%d %H:%M'))"
        echo "# Po změně spusť: docker compose up -d"
    } >> "$DIR/.env"
    env_set KLIENT_REF "$DEFAULT_KLIENT_REF"
    env_set SERVER_REF "$DEFAULT_SERVER_REF"
    configure_companion
    port="${WEB_PORT:-}"; [ -n "$port" ] || { ask "Port webového rozhraní" "8080"; port="$REPLY"; }
    tz="${TZ:-$(cat /etc/timezone 2>/dev/null || timedatectl show -p Timezone --value 2>/dev/null || echo Europe/Prague)}"
    env_set WEB_PORT "$port"
    env_set TZ "${tz:-Europe/Prague}"
    env_set NODE_NAME ""
    env_set DB_ROOT_PASSWORD "$(gen_pw 32)"
    env_set KLIENT_DB_PASSWORD "$(gen_pw 32)"
    env_set SERVER_DB_PASSWORD "$(gen_pw 32)"
    env_set MC_SERVER_TOKEN ""
    env_set ADMIN_USER "${ADMIN_USER:-admin}"
else
    info "Aktualizace instalace v $DIR"
    [ "${RECONFIGURE:-0}" = 1 ] && configure_companion
fi

# ---------------------------------------------------------------- zdrojáky a sestavení

KLIENT_REF="$(env_get KLIENT_REF)"; KLIENT_REF="${KLIENT_REF:-$DEFAULT_KLIENT_REF}"
SERVER_REF="$(env_get SERVER_REF)"; SERVER_REF="${SERVER_REF:-$DEFAULT_SERVER_REF}"
download meshcore-server "$SERVER_REF" "$DIR/src/meshcore-server"
download meshcore-klient "$KLIENT_REF" "$DIR/src/meshcore-klient"
[ -f "$DIR/src/meshcore-klient/Dockerfile" ] || die "Klient verze $KLIENT_REF nemá Dockerfile – je potřeba novější verze."

info "Sestavuji image (poprvé to může trvat několik minut, na Raspberry Pi i 15 minut)"
dc build --pull

info "Spouštím databázi a meshcore-server"
# --wait: počkat, až je server zdravý (má hotové schéma DB) – teprve pak se smí vytvářet token,
# jinak by se zakládání schématu serverem a příkazem „token create“ srazilo.
if ! dc up -d --wait --wait-timeout 300 db meshcore-server; then
    dc logs --tail=30 meshcore-server >&2 || true
    die "meshcore-server se nespustil – viz výpis výše."
fi

# API token klienta pro server (jen jednou)
if [ -z "$(env_get MC_SERVER_TOKEN)" ]; then
    info "Propojuji klienta se serverem (API token)"
    token=""
    for _ in $(seq 1 30); do
        out="$(cd "$DIR" && timeout 60 "${DOCKER[@]}" compose exec -T meshcore-server meshcore-server token create "meshcore-klient-$(date +%s)" --scope admin < /dev/null 2>&1 || true)"
        token="$(printf '%s\n' "$out" | grep -oE 'mcs_[A-Za-z0-9_-]+' | head -1 || true)"
        [ -n "$token" ] && break
        sleep 3
    done
    [ -n "$token" ] || { printf '%s\n' "$out" >&2; die "Token se nepodařilo vytvořit – viz 'docker compose logs meshcore-server'."; }
    env_set MC_SERVER_TOKEN "$token"
    ok "Token vytvořen a uložen do .env"
fi

info "Spouštím klienta"
dc up -d --remove-orphans

# uživatel webu (jen při první instalaci)
ADMIN_PW=""
ADMIN_USER="$(env_get ADMIN_USER)"; ADMIN_USER="${ADMIN_USER:-admin}"
# uživatel webu – jen když zatím žádný není (první instalace nebo přerušená instalace)
users=""
for _ in $(seq 1 40); do
    if users="$(dc exec -T klient-web php bin/user.php list 2>/dev/null)"; then break; fi
    users="?"; sleep 3
done
if [ -z "$users" ]; then
    ADMIN_PW="$(gen_pw 16)"
    dc exec -T klient-web php bin/user.php add "$ADMIN_USER" "--password=$ADMIN_PW" >/dev/null \
        || { warn "Uživatele se nepodařilo vytvořit – vytvoř ho ručně (viz README)."; ADMIN_PW=""; }
elif [ "$users" = "?" ]; then
    warn "Klient zatím neodpovídá – uživatele vytvoř ručně: docker compose exec klient-web php bin/user.php add admin --password=…"
fi

# ---------------------------------------------------------------- shrnutí

ip="$(hostname -I 2>/dev/null | awk '{print $1}')"
port="$(env_get WEB_PORT)"
echo
ok "${c_b}MeshCore stack běží.${c_0}"
echo
echo "  Web:       http://${ip:-localhost}:${port:-8080}/"
if [ -n "$ADMIN_PW" ]; then
    echo "  Uživatel:  $ADMIN_USER"
    echo "  Heslo:     $ADMIN_PW"
    echo
    echo "  ${c_warn}Heslo si ulož – znovu se nezobrazí.${c_0} Změníš ho v klientu: menu ⋮ → Heslo k přihlášení."
fi
echo
echo "  Složka:    $DIR   (nastavení v .env)"
echo "  Stav:      cd $DIR && docker compose ps"
echo "  Logy:      cd $DIR && docker compose logs -f meshcore-server klient-worker"
echo "  Aktualizace: spusť instalační příkaz znovu"
echo

}

main "$@"
