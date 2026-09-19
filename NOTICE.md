# Third-party notices

VoidrauVPN stages independent open-source components next to the app at build
time (see `scripts/fetch_cores.sh` and `scripts/pins.json`). Each one remains
under its own license and is used unmodified. VoidrauVPN is an independent
client and is not endorsed by those projects.

This file exists purely for license compliance of the redistributed binaries —
nothing in it is shown inside the app.

- Tunnel core — by its respective authors — MIT
- hev-socks5-tunnel — heiher — GPL-2.0
- tun2socks — xjasonlyu — GPL-3.0
- WinTUN — WireGuard LLC — MIT (https://www.wintun.net/)

The full license text of each component is distributed with its release archive;
keep those files next to the binaries when you republish a build.
