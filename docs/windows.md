# Instalace na Windows

Stack běží v Linuxu uvnitř Windows (WSL 2) s Docker Desktopem.

1. **Nainstaluj WSL** – v PowerShellu spuštěném jako správce:
   ```powershell
   wsl --install -d Ubuntu
   ```
   Restartuj počítač. Po restartu se otevře okno Ubuntu, kde zadáš jméno a heslo nového linuxového uživatele.
2. **Nainstaluj [Docker Desktop](https://www.docker.com/products/docker-desktop/)** a v jeho nastavení zapni
   *Settings → Resources → WSL integration → Ubuntu*.
3. **Otevři Ubuntu** (nabídka Start → Ubuntu) a spusť stejný příkaz jako na Linuxu:
   ```bash
   curl -fsSL https://raw.githubusercontent.com/pmalecek/meshcore-stack/main/install.sh | bash
   ```
4. Web otevři ve Windows na `http://localhost:8080/` (adresa, kterou instalátor vypíše, platí uvnitř WSL;
   z Windows funguje `localhost`).

Poznámky:

- Docker Desktop musí běžet (ikona velryby v oznamovací oblasti), jinak stack neběží. Pro trvalý provoz
  zapni v Docker Desktopu *Start Docker Desktop when you sign in*.
- **Companion přes WiFi (TCP) je na Windows nejjednodušší.** USB do WSL jde předat nástrojem
  [usbipd-win](https://github.com/dorssel/usbipd-win) (`usbipd bind` a `usbipd attach --wsl`), pak postupuj
  podle [usb.md](usb.md). Bluetooth z WSL nefunguje.
- Ostatní zařízení v síti se k webu na Windows dostanou až po povolení portu ve Windows firewallu; pro trvalý
  provoz je vhodnější Linux (mini PC, Raspberry Pi, VPS).
