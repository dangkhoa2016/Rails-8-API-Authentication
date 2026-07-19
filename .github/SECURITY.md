# Security Policy

## Supported Versions

| Version | Supported          |
|---------|--------------------|
| latest  | :white_check_mark: |

## Reporting a Vulnerability

Please report security vulnerabilities by opening a [GitHub Security Advisory](https://github.com/dangkhoa2016/Rails-8-API-Authentication/security/advisories/new).

Do NOT report security vulnerabilities via public GitHub Issues.

You should receive a response within 72 hours. If you don't, please follow up.

## Supported Environments

This project is designed to run in a secure server environment with:
- HTTPS enforced in production
- Encrypted credentials via `RAILS_MASTER_KEY`
- Rate limiting on authentication endpoints
- JWT denylist for revoked tokens
