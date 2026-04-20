# Mouse Configuration (Bazzite)

## Devices

| Mouse | Connection | USB ID | Config tool |
|---|---|---|---|
| Razer Basilisk V3 Pro 35K | Wireless via Mouse Dock Pro | Dock: `1532:00a4`, Wired: `1532:00cc`, Wireless: `1532:00cd` | RazerGenie or Polychromatic |
| Logitech G502 X Plus | Wireless via Lightspeed receiver | Receiver: `046d:c547` | Piper |

### Which tool does what

- **Piper** — Logitech only. Uses libratbag/ratbagd. Configures DPI stages, button mapping, profiles, poll rate.
- **RazerGenie** — Razer only. Simple Qt frontend for openrazer. DPI, poll rate, lighting.
- **Polychromatic** — Razer only. More full-featured GTK frontend. Profiles, DPI stages, button mapping, lighting effects, battery.

Piper is already layered via rpm-ostree. RazerGenie and Polychromatic are Flatpaks.

---

## Razer — OpenRazer + GUI Frontend

Bazzite includes a `ujust install-openrazer` recipe, but the manual steps below are more reliable.

### Known issue: akmods version mismatch

The openrazer kernel modules in `kernel-modules-akmods` may lag behind the daemon version.
As of March 2026: daemon is 3.12.0, kernel modules are 3.10.2. The Mouse Dock Pro (`1532:00a4`)
was added after 3.10.2, so **the daemon cannot detect the mouse at all until the akmods are rebuilt**.
Both wired and wireless go through the dock (`00a4`), so there is no workaround — the mouse
works as a basic HID device but no profile/DPI/button configuration is possible.
Tracked in [ublue-os/bazzite#3777](https://github.com/ublue-os/bazzite/issues/3777).

After the akmods are updated, the modules should auto-bind via udev. If they don't, see
the "Kernel modules" section below.

### 1. Install openrazer-daemon (if not already layered)

```sh
rpm -q openrazer-daemon || sudo rpm-ostree install openrazer-daemon
```

### 2. Add plugdev group and membership

The `plugdev` group exists in `/usr/lib/group` (immutable layer) but not in `/etc/group`. It must be added manually:

```sh
if ! grep -q "plugdev" /etc/group; then
  sudo sh -c 'echo "plugdev:x:46:$SUDO_USER" >> /etc/group'
else
  sudo usermod -aG plugdev "$USER"
fi
```

### 3. Kernel modules

The openrazer kernel modules (`razermouse`, `razeraccessory`) may not autoload at boot.
Ensure they load on every boot:

```sh
sudo tee /etc/modules-load.d/openrazer.conf >/dev/null <<'EOF'
razermouse
razeraccessory
EOF
```

### 4. Enable the daemon

```sh
systemctl --user enable openrazer-daemon
```

### 5. Install GUI frontend (Flatpak)

```sh
flatpak install -y flathub xyz.z3ntu.razergenie
flatpak install -y flathub app.polychromatic.controller
```

### 6. Reboot

Required for plugdev group membership, module loading, and udev device permissions to take effect.

### Post-reboot verification

```sh
groups | grep -q plugdev && echo "plugdev: OK" || echo "plugdev: MISSING"
systemctl --user is-active openrazer-daemon && echo "daemon: OK" || echo "daemon: NOT RUNNING"
lsmod | grep -q razermouse && echo "razermouse: loaded" || echo "razermouse: NOT LOADED"
lsmod | grep -q razeraccessory && echo "razeraccessory: loaded" || echo "razeraccessory: NOT LOADED"
# Check if the dock is detected (empty array = akmods version mismatch, wait for update)
dbus-send --session --dest=org.razer --type=method_call --print-reply /org/razer razer.devices.getDevices
```

---

## Logitech G502 X Plus — Piper / libratbag

Piper (`piper` package, already layered) uses libratbag via `ratbagd`. The G502 X device definition exists in libratbag (`logitech-g502-x-wireless.device`).

### Kernel requirement

The Lightspeed receiver `046d:c547` needs kernel **6.19+** for the `hid-logitech-dj` driver to recognise it. On older kernels it falls back to `hid-generic` and ratbagd/Piper cannot see the mouse.

- **Kernel 6.19**: commit `5329fc30cbea` added `c547` as `NANO_RECEIVER_LIGHTSPEED_1_3`
- **Fedora 43**: 6.19 is in the testing repo, expected in stable soon
- **Fedora 44**: ships with 6.19 (release April 2026)

No manual steps needed — once the kernel lands via a normal system update, the G502 X will work with Piper automatically.

### Post-update verification

```sh
ratbagctl list
# Should show the G502 X Plus. If empty, check:
uname -r  # must be 6.19+
lsmod | grep hid_logitech_dj  # must be loaded
```

---

## Troubleshooting

### Mouse goes dead after driver rebind

If you unbind a device from `hid-generic` without a working target driver, the mouse stops working.
To restore it, rebind the HID interfaces back to `hid-generic`:

```sh
# Find the device's HID interfaces
ls /sys/bus/hid/devices/ | grep 1532:00A4  # for Razer dock
ls /sys/bus/hid/devices/ | grep 046D:C547  # for Logitech receiver

# Rebind each interface (replace XXXX with the suffix, e.g. 0008)
echo -n "0003:1532:00A4.XXXX" | sudo tee /sys/bus/hid/drivers/hid-generic/bind
```

### Checking which driver owns a device

```sh
for d in /sys/bus/hid/devices/0003:1532:00A4.*; do
  echo "$(basename $d): driver=$(basename $(readlink $d/driver 2>/dev/null) 2>/dev/null)"
done
```

Replace `1532:00A4` with `046D:C547` for the Logitech receiver.

---

## Summary — what to add to install-bazzite.sh

```sh
# --- Mouse support ---
# Razer: plugdev group (required for openrazer-daemon)
if ! grep -q "plugdev" /etc/group; then
  sudo sh -c 'echo "plugdev:x:46:'"$USER"'" >> /etc/group'
else
  sudo usermod -aG plugdev "$USER"
fi

# Razer: ensure kernel modules load at boot
sudo tee /etc/modules-load.d/openrazer.conf >/dev/null <<'EOF'
razermouse
razeraccessory
EOF

# Razer: enable daemon
systemctl --user enable openrazer-daemon

# Razer: GUI frontends
flatpak install -y flathub xyz.z3ntu.razergenie
flatpak install -y flathub app.polychromatic.controller

# Logitech G502 X Plus: requires kernel 6.19+ (no action needed, piper already layered)
```
