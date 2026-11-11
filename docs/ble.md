# Companion přes Bluetooth (pokročilé)

Bluetooth v Dockeru závisí na hostiteli a nefunguje všude (např. ne na Windows/WSL ani v Proxmox LXC bez
předání adaptéru). **Pokud to jde, použij WiFi nebo USB.**

Kontejner serveru používá Bluetooth hostitele přes D-Bus (BlueZ), proto musí Bluetooth fungovat na hostiteli:

1. **Bluetooth na hostiteli:**
   ```bash
   sudo apt install bluez
   sudo systemctl enable --now bluetooth
   bluetoothctl show            # musí vypsat adaptér (Powered: yes)
   ```
2. **Najdi companion a spáruj ho** (PIN je na displeji companionu nebo v aplikaci MeshCore, výchozí 123456):
   ```bash
   bluetoothctl
   scan on                      # počkej, až se objeví MeshCore-…, zapiš si MAC adresu
   scan off
   pair AA:BB:CC:DD:EE:FF       # zadej PIN
   trust AA:BB:CC:DD:EE:FF
   exit
   ```
   Companion nesmí být zároveň připojený k telefonu – BLE spojení může mít jen jedno.
3. **Spusť instalátor a zvol 3) Bluetooth.** Zadej MAC adresu a PIN.

Stack pak použije `compose.ble.yml`: připojí do kontejneru D-Bus hostitele (`/run/dbus`) a přidá oprávnění
pro Bluetooth.

Když se server nepřipojí (`docker compose logs meshcore-server`):

- ověř, že spárování na hostiteli platí (`bluetoothctl info AA:BB:CC:DD:EE:FF` → `Paired: yes`),
- companion musí být v dosahu (BLE má jednotky metrů, zdi hodně tlumí),
- na některých systémech je potřeba spustit kontejner v síti hostitele – do `compose.ble.yml` přidej
  u `meshcore-server` řádek `network_mode: host` a v `docker-compose.yml` změň u klienta
  `MC_SERVER_URL` na `http://host.docker.internal:8080` s `extra_hosts: ["host.docker.internal:host-gateway"]`.

Spolehlivější alternativa: spusť meshcore-server přímo na hostiteli (pip + systemd, viz jeho README) a v
`.env` klienta nastav jeho adresu.
