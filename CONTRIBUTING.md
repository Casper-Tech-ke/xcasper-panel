<div align="center">

<img src="https://readme-typing-svg.demolab.com?font=Fira+Code&weight=700&size=26&duration=3000&pause=1000&color=4ade80&center=true&vCenter=true&width=700&lines=Contributing+to+XCASPER+Panel;We+Believe+in+Building+Together;Casper+Tech+Kenya+🇰🇪" alt="Contributing" />

[![PRs Welcome](https://img.shields.io/badge/PRs-Welcome-4ade80?style=for-the-badge)](https://github.com/Casper-Tech-ke/xcasper-panel/pulls)
[![Issues](https://img.shields.io/badge/Issues-Open-00D4FF?style=for-the-badge)](https://github.com/Casper-Tech-ke/xcasper-panel/issues)
[![Telegram](https://img.shields.io/badge/Chat-Telegram-7C3AED?style=for-the-badge&logo=telegram)](https://t.me/casper_tech_ke)

</div>

---

## 💙 We Believe in Building Together

Thank you for considering contributing to XCASPER Panel! Every contribution — no matter how small — helps make the panel better for the entire African hosting community.

---

## 🛠 Ways to Contribute

| Type | Description |
|------|-------------|
| 🐛 Bug Reports | Found something broken? Open an issue with steps to reproduce |
| 💡 Feature Requests | Have an idea? We'd love to hear it — open a discussion |
| 🔧 Bug Fixes | Pick an open bug and submit a fix |
| ✨ New Features | Implement something from the issues list |
| 📖 Documentation | Improve guides, examples, or inline comments |
| 🌍 Translations | Help translate the panel interface |
| 🧪 Testing | Write tests or report edge cases |

---

## 📋 Before You Start

1. **Check existing issues** — someone may already be working on it
2. **Open an issue first** for large changes, to align on approach
3. **Join Telegram** — [t.me/casper_tech_ke](https://t.me/casper_tech_ke) for quick questions

---

## 🔄 Development Workflow

```bash
# Fork the repo on GitHub, then:
# Clone your fork locally
# Create a feature branch
# Make your changes
# Build frontend if you changed TypeScript/React files:
yarn build

# Run tests
php artisan test

# Commit with a descriptive message (see format below)
# Push and open a Pull Request
```

---

## 📝 Commit Message Format

We follow [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>(<scope>): <short description>

Types: feat | fix | docs | style | refactor | test | chore

Examples:
  feat(billing): add wallet transaction history page
  fix(auth): correct reCAPTCHA positioning on mobile
  docs(super-admin): improve colour tab documentation
  style(login): apply CSS variable theming to button
  refactor(billing): extract payment verification to service
  chore(deps): update Laravel to 9.52
```

---

## 🎨 Code Style

### PHP (Laravel)
- Follow [PSR-12](https://www.php-fig.org/psr/psr-12/) coding standard
- Use strict type hints and return types everywhere
- Keep controllers thin — business logic goes in Service classes

### TypeScript / React
- Use functional components with hooks (no class components)
- Use `styled-components` for all styling
- **Never hardcode hex colours** — always use `var(--xcasper-primary)` / `var(--xcasper-accent)`
- Use `rgba(var(--xcasper-primary-rgb), 0.x)` for transparent variants

### Blade Templates
- Keep templates clean; extract repeating HTML into components
- Inject dynamic CSS via the `wrapper.blade.php` pattern

---

## ✅ Pull Request Checklist

Before submitting your PR, please confirm:

- [ ] Code follows the style guidelines above
- [ ] Changes tested locally and working
- [ ] Frontend changes built (`yarn build`)
- [ ] No `.env` or sensitive data committed
- [ ] Documentation updated where relevant
- [ ] PR title follows conventional commit format

---

## 🙏 Recognition

All contributors are appreciated! Significant contributions earn:

- A mention in `CHANGELOG.md`
- A shoutout on [@casper_tech_ke Telegram](https://t.me/casper_tech_ke)
- Credit in the project README contributors section

---

<div align="center">

### 👻 Built with love in Kenya

[![Telegram](https://img.shields.io/badge/Telegram-Support-00D4FF?style=flat-square&logo=telegram)](https://t.me/casper_tech_ke)
[![Website](https://img.shields.io/badge/Website-xcasper.space-7C3AED?style=flat-square)](https://xcasper.space)
[![GitHub](https://img.shields.io/badge/GitHub-@Casper--Tech--ke-000?style=flat-square&logo=github)](https://github.com/Casper-Tech-ke)

**© 2025–2026 Casper Tech Kenya Developers. All rights reserved.**

*A [CASPER TECH KENYA](https://xcasper.space) product — we believe in building together.*

</div>
