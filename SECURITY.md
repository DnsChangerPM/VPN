# Security

Report vulnerabilities privately via GitHub Security Advisories on this repository.

Nimbus launches the official Aether core as a local SOCKS5 process and, in VPN mode, routes a TUN adapter through that proxy. The SOCKS listener is `127.0.0.1:1819` unless LAN sharing is enabled — do not expose it on untrusted networks.

Release artifacts should be verified against `SHA256SUMS.txt` on the GitHub Release.
