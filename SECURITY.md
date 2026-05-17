# Security Policy

## Supported Versions

| Version | Supported |
|---------|-----------|
| 1.x.x   | ✅ Yes    |

## Reporting a Vulnerability

If you discover a security vulnerability, **please do not open a public issue.**

Report it privately via one of the following:

- **GitHub:** Open a [Security Advisory](https://github.com/Mcdikmen/mcSentinel/security/advisories/new)
- **Discord Server:** [discord.gg/de8fABdPyf](https://discord.gg/de8fABdPyf)
- **Discord:** mcdikmen
- **Email:** muratcan.dikmen@outlook.com

Please include:
- A clear description of the vulnerability
- Steps to reproduce
- Potential impact
- Suggested fix (if any)

You will receive a response within **48 hours**. Once the issue is confirmed and patched, a new release will be published and you will be credited (unless you prefer to remain anonymous).

## Security Considerations

- Admin access is controlled via FiveM ace permissions (`mcSentinel.admin`)
- All server-side event handlers validate admin status before processing requests
- Database queries use parameterized statements — no raw string concatenation
- Live alert broadcasts strip sensitive fields (e.g. IP addresses) before sending to clients
- The Discord webhook URL is never exposed to clients
