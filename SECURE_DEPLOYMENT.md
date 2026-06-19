# A4ther FFScanner — Secure Deployment (v4.4.94)

## 🔐 Passphrase Management

The encrypted `.enc` files require a passphrase for decryption.

### For Security Researchers / Contributors

Contact: [your-contact-method]
- **Do NOT** request passphrase in public issues/PRs
- **Do** request via private channel (email, Signal, etc)
- Passphrase rotates on security incidents

### For CI/CD / Production Environments

Store passphrase as a GitHub Secret:

```bash
# GitHub Actions
- name: Use Encrypted Scanner
  env:
    FF_PASSPHRASE: ${{ secrets.FF_PASSPHRASE }}
  run: |
    curl -s https://raw.githubusercontent.com/lovelyoyk/a4ther/main/decrypt.sh | sh decrypt.sh a4ther.sh.enc | sh
```

### For Local Development

```bash
# Store in local .env file (never commit)
echo 'export FF_PASSPHRASE="[your-passphrase]"' >> ~/.a4ther.env
source ~/.a4ther.env

# Then use:
sh decrypt.sh a4ther.sh.enc | sh
```

---

## ⚠️ Security Notes

- **Passphrase is NOT public** — request separately from repository
- **Never commit .env files** containing the passphrase
- **Rotate passphrase** if:
  - Team member leaves
  - Credentials leaked
  - Security incident
  - Regular schedule (quarterly recommended)

---

## 🔄 Migration Path

### From Fluxo 1 (Compatible) → Fluxo 2 (Protected):

```bash
# If you already have the compatible version:
curl -s https://raw.githubusercontent.com/lovelyoyk/a4ther/main/a4ther.sh | sh

# To switch to encrypted version:
export FF_PASSPHRASE="[request from maintainer]"
curl -s https://raw.githubusercontent.com/lovelyoyk/a4ther/main/decrypt.sh | sh decrypt.sh a4ther.sh.enc | sh
```

---

**Latest Release:** v4.4.94-HYBRID  
**Last Updated:** 2026-06-19
