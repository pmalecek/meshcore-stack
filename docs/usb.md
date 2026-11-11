# Companion přes USB

1. Připoj companion USB kabelem k počítači, kde poběží stack.
2. Zjisti jeho sériový port:
   ```bash
   ls -l /dev/serial/by-id/ /dev/ttyACM* /dev/ttyUSB* 2>/dev/null
   ```
   Nejspolehlivější je cesta z `/dev/serial/by-id/…` – nezmění se, ani když připojíš další zařízení.
3. Spusť instalátor a zvol **2) USB**. Nabídne první nalezený port; potvrď ho nebo zadej jiný.

Instalátor zařízení předá do kontejneru serveru (`compose.usb.yml`) a nastaví skupinu, která k němu má přístup
(`COMPANION_DEVICE_GID` v `.env`, obvykle `dialout` = 20).

Když server hlásí, že port nejde otevřít:

- zkontroluj, že companion je připojený a port v `.env` (`COMPANION_DEVICE`) existuje,
- port nesmí mít otevřený jiný program (např. Home Assistant nebo sériový monitor),
- po odpojení a připojení companionu restartuj server: `docker compose restart meshcore-server`.

Firmware companionu musí být verze pro USB (*Companion USB*). Rychlost je výchozí 115200 Bd
(`COMPANION_BAUDRATE` v `.env`).
