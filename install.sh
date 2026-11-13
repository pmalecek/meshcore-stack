#!/usr/bin/env bash
# MeshCore stack – instalace (meshcore-server + meshcore-klient + MariaDB v Dockeru).
#
#   curl -fsSL "https://raw.githubusercontent.com/pmalecek/meshcore-stack/main/install.sh?$(date +%s)" | bash
#
# Stáhne stack do ~/meshcore-stack, zpřístupní příkaz „meshcore-stack“ a spustí instalaci.
# Na existující instalaci provede aktualizaci. Další správa: příkaz meshcore-stack (menu).
#
# Proměnné prostředí (nepovinné):
#   MESHCORE_DIR       kam instalovat (výchozí ~/meshcore-stack)
#   STACK_REF          verze tohoto repozitáře (výchozí main)
#   Neinteraktivní instalace: COMPANION_TRANSPORT=tcp|usb|ble a COMPANION_HOST (COMPANION_PORT) /
#   COMPANION_DEVICE / COMPANION_BLE_ADDRESS, volitelně WEB_PORT, TZ, ADMIN_USER.
set -euo pipefail

# Vše ve funkci: bash při „curl … | bash“ načte celý skript dřív, než cokoli spustí.
main() {
    local github="${MESHCORE_GITHUB:-https://github.com/pmalecek}"
    local ref="${STACK_REF:-main}"
    local dir="${MESHCORE_DIR:-$HOME/meshcore-stack}"

    command -v curl >/dev/null || { echo "✘ Chybí curl (apt install curl)." >&2; exit 1; }
    command -v tar >/dev/null  || { echo "✘ Chybí tar." >&2; exit 1; }
    if ! command -v docker >/dev/null; then
        cat >&2 <<'TXT'
✘ Docker není nainstalovaný. Na Debianu / Ubuntu / Raspberry Pi OS:
    curl -fsSL https://get.docker.com | sudo sh
    sudo usermod -aG docker $USER      # pak se odhlas a přihlas
Windows: viz docs/windows.md v repozitáři meshcore-stack.
TXT
        exit 1
    fi
    if ! command -v whiptail >/dev/null && command -v apt-get >/dev/null; then
        echo "Tip: pro dialogy v terminálu nainstaluj whiptail (sudo apt install whiptail). Funguje to i bez něj."
    fi

    echo "==> Stahuji meshcore-stack ($ref) do $dir"
    local tmp; tmp="$(mktemp -d)"
    curl -fsSL "$github/meshcore-stack/archive/$ref.tar.gz" -o "$tmp/stack.tar.gz" \
        || { rm -rf "$tmp"; echo "✘ Stažení selhalo." >&2; exit 1; }
    mkdir -p "$tmp/x" "$dir"
    tar -xzf "$tmp/stack.tar.gz" -C "$tmp/x" --strip-components=1
    # .env, zdrojáky a zálohy se nepřepisují
    (cd "$tmp/x" && tar -cf - --exclude=./.env --exclude=./src --exclude=./backups .) | (cd "$dir" && tar -xf -)
    rm -rf "$tmp"
    chmod +x "$dir/meshcore-stack" "$dir/install.sh" "$dir"/db/init/*.sh 2>/dev/null || true

    export MESHCORE_DIR="$dir" STACK_REF="$ref"
    if { : < /dev/tty; } 2>/dev/null; then
        exec "$dir/meshcore-stack" install < /dev/tty
    else
        exec "$dir/meshcore-stack" install < /dev/null
    fi
}

main "$@"
