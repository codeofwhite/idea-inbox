# Security

Idea Inbox 0.1.0 is an early development version. It has not received an independent security audit. Security fixes currently target the latest source version; older versions have no maintenance guarantee.

## Reporting

Please do not disclose exploitable vulnerabilities in public issues.

If GitHub shows a **Report a vulnerability** button in this repository's Security tab, use that private reporting channel. Private reporting may not yet be enabled. Otherwise, open an issue titled "Request for private security contact" with no vulnerability details, credentials, notes or personal information, and wait for the maintainer to arrange a private channel.

Do not upload databases, backups, pairing QR codes, bearer tokens, TLS private keys or platform secure-storage files. Use synthetic data and redact device/network identifiers.

## Design boundaries

- Foreground manual sync on a trusted private IPv4 LAN between one Android phone and one Windows PC.
- QR pairing requires confirmation on the PC; the phone pins the PC certificate's SHA-256 fingerprint.
- Notes and exports are not encrypted at rest by the application.
- Pairing credentials and private keys use platform secure storage.
- Revocation blocks future requests; it cannot erase already-synchronized data.
- Sync propagates changes and deletion markers. Maintain separate backups.
- No pagination, rate limiting or protection against an already-trusted malicious peer is claimed.
- The application does not configure a public endpoint or firewall exceptions. Do not expose the listener to the internet.

See [the protocol](docs/sync-protocol.md) and [README](README.md) for limits and failure semantics.
