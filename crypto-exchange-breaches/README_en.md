# Korean crypto exchange breaches — Bithumb's 15-day intrusion and the adjacent systems

[한국어](README.md) | [English](README_en.md)

Bithumb's internal groupware (Daou Office) compromise lasted **15 days, from October 12 to 27** — not the one hour initially announced — according to an update on November 25. Five Korean crypto exchanges were breached in October and November, and the entry points were **groupware, outsourced support staff, and hot wallets**, not cold wallets.

## Bithumb

- Intrusion period: **2026-10-12 to 10-27** (15 days)
- Scope: expanded from 7,159 to customers, partners, and current/former employees (additional headcount undisclosed)
- Data: 19 fields including resident registration numbers, passports, driver's licenses, ID card copies, account numbers, transaction history, and wallet addresses

## Five exchanges

| Exchange | Detail |
| --- | --- |
| Bithumb | Groupware (Daou Office) intrusion for 15 days; 19 fields |
| Coinone | Outsourced support vendor MetaM breached — 11 fields potentially including passwords, resident numbers, wallet addresses |
| Gopax | September breach grew from 9 to 2,009 people; an 11/6 extortion email halted deposits and withdrawals for over 15 days |
| Prava | About KRW 100 million taken from a hot wallet on 10/24 |
| Flybit | 40 customers exposed on 11/1 via a Daou Technology groupware path |

## Common pattern

- **Groupware and collaboration tools** are the initial entry point (Bithumb and Flybit both via Daou Office / Daou Technology)
- **Outsourced support and contractor accounts** retain customer-data access
- **Hot wallets** remain an online fund path
- Intrusion periods are longer than announced — never treat the first statement as the final scope

## Checklist

### Exchanges and fintech

- [ ] Enforce MFA on groupware; block abnormal-location and abnormal-time logins
- [ ] Detect document exfiltration (bulk downloads, external mail) with alerts
- [ ] Issue separate credentials for vendors/contractors, limit scope and duration, monitor usage
- [ ] Hot wallet balance caps, multi-signature, withdrawal time locks
- [ ] Confirm **log retention** and forensic procedure before any breach notice

### Users

- [ ] Block exchange impersonation phishing and **wallet-address change requests** (verify only via the official app and notices)
- [ ] Re-check withdrawal address books; set a waiting period after adding a new address
- [ ] Reset passwords and authentication factors, anticipating misuse of leaked IDs and account numbers

### General enterprises

- [ ] Review how a single groupware account compromise exposes documents, mail, and the address book
- [ ] Segregate contractor networks and separate API keys

## References

- Yonhap — Bithumb 15-day update: https://www.yna.co.kr/view/AKR20261125176100002
- Seoul Shinmun — Five exchanges: https://www.seoul.co.kr/news/economy/2026/11/15/20261115500055
- Coinone official notice: https://coinone.co.kr/info/notice/5950

Verified as of 2026-11-26.
