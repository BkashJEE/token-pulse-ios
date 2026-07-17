# Security

Report security issues privately to the repository maintainer. Do not include live server URLs, keys, or private session titles in public reports.

The iOS app accepts HTTPS Token Pulse servers, stores the read key in Keychain, and never stores the desktop write token. Production builds should enforce a stable HTTPS domain and complete device-level network and Keychain testing before release.
