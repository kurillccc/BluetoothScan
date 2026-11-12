# MMLanScan

Source: https://github.com/getmemd/MMLANScannerSPM
Revision: c6ef984dff9d7f9f00fa2b661e4fee13ced4927b
Original project: https://github.com/mavris/MMLanScan

Local changes:
- Discover devices from successful ICMP responses without requiring a MAC address.
- Calculate IPv4 host ranges using integer arithmetic; reject ranges over 4094 hosts.
- Avoid blocking the caller when cancelling a scan.
- Deliver progress on the main queue and ignore callbacks from cancelled runs.
- Guard interface pointers and release hostname lookup resources.

The original MIT license and Apple SimplePing notices are retained.

The scanner and SimplePing sources are compiled directly in the app target. Unused ARP/vendor lookup code and package wrapper are omitted.
