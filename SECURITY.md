<div align="center">

<img src="https://readme-typing-svg.demolab.com?font=Fira+Code&weight=700&size=26&duration=3000&pause=1000&color=f87171&center=true&vCenter=true&width=700&lines=XCASPER+Panel+—+Security+Policy;Responsible+Disclosure;Casper+Tech+Kenya+🇰🇪" alt="Security" />

[![Security](https://img.shields.io/badge/Security-Policy-f87171?style=for-the-badge&logo=shield&logoColor=white)](SECURITY.md)
[![Email](https://img.shields.io/badge/Email-caspertechke%40gmail.com-00D4FF?style=for-the-badge&logo=gmail&logoColor=white)](mailto:caspertechke@gmail.com)
[![Telegram](https://img.shields.io/badge/Telegram-%40casper__tech__ke-7C3AED?style=for-the-badge&logo=telegram)](https://t.me/casper_tech_ke)

</div>

---

## 🛡 Supported Versions

| Version | Supported |
|---------|-----------|
| `main` branch (latest) | ✅ Actively maintained |
| Older tagged releases | ⚠ Best-effort only |

---

## 🔍 Scope

**In scope** for security reports:

- Authentication bypass or privilege escalation
- SQL injection, XSS, CSRF vulnerabilities in XCASPER-added code
- Exposed API keys or secrets in committed files
- IDOR in billing or user management APIs
- Super Admin panel unauthorized access
- Paystack payment verification bypass
- RCE via malicious egg config or file upload

**Out of scope:**

- Issues in upstream Pterodactyl — report to [pterodactyl/panel](https://github.com/pterodactyl/panel/security)
- Rate limiting / DDoS (infrastructure level)
- Issues requiring physical server access
- Social engineering

---

## 📢 How to Report

**Please do not open a public GitHub issue for security vulnerabilities.**

| Method | Details |
|--------|---------|
| 📧 Email | [caspertechke@gmail.com](mailto:caspertechke@gmail.com) — Subject: `[SECURITY] Panel — <description>` |
| 💬 Telegram | [@casper_tech_ke](https://t.me/casper_tech_ke) — Start with `[SECURITY REPORT]` |
| 🔒 GitHub Advisory | [Private security advisory](https://github.com/Casper-Tech-ke/xcasper-panel/security/advisories/new) |

### What to Include

```
- Type of vulnerability
- Affected component (file, endpoint, feature)
- Steps to reproduce
- Proof of concept (if available)
- Estimated severity / impact
- Your contact information
```

---

## ⏱ Response Timeline

| Stage | Target |
|-------|--------|
| Acknowledgement | ≤ 48 hours |
| Triage & assessment | ≤ 5 business days |
| Patch (critical) | ≤ 14 days |
| Patch (high) | ≤ 30 days |
| Coordinated disclosure | Agreed with reporter |

---

## 🔒 Built-in Security Measures

| Measure | Details |
|---------|---------|
| Email validation | 6-layer: domain allowlist, Gmail format rules, 30+ fake prefix blocks, MX DNS check |
| Super Admin auth | Session-based key lock, completely separate from panel user auth |
| CSRF protection | Laravel CSRF tokens on all forms and API calls |
| Paystack verification | Server-side signature check on all webhooks and payment confirmations |
| Secret management | All sensitive keys stored in `.env` — never committed |
| Rate limiting | Laravel throttle middleware on all auth and billing endpoints |
| reCAPTCHA | Google reCAPTCHA v2 on login and registration forms |

---

## 🙏 Recognition

Valid, responsibly disclosed security reports will be acknowledged in:

- `CHANGELOG.md`
- A personal shoutout from [@Casper-Tech-ke](https://github.com/Casper-Tech-ke)
- The project Hall of Fame (coming soon)

---

<div align="center">

### 👻 Built with love in Kenya

[![Telegram](https://img.shields.io/badge/Telegram-Support-00D4FF?style=flat-square&logo=telegram)](https://t.me/casper_tech_ke)
[![Website](https://img.shields.io/badge/Website-xcasper.space-7C3AED?style=flat-square)](https://xcasper.space)
[![GitHub](https://img.shields.io/badge/GitHub-@Casper--Tech--ke-000?style=flat-square&logo=github)](https://github.com/Casper-Tech-ke)

**© 2025–2026 Casper Tech Kenya Developers. All rights reserved.**

*A [CASPER TECH KENYA](https://xcasper.space) product — we believe in building together.*

</div>
