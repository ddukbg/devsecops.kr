# Securities API defense rulebook — token exchange, cardinality rate limiting, SQLi blocking

[한국어](README.md) | [English](README_en.md)

The incident reports behind the Daishin Securities (38,490) and Mirae Asset Securities (39,055) breaches — 77,545 records in total — spelled out three holes. "Please patch" does not prevent a repeat, so this is written as patterns you can put into code.

## Three holes the incidents revealed

| Incident | Method | Failed control |
| --- | --- | --- |
| Daishin Securities (10/17) | Malware on a DMZ server → admin API key theft → valid token issued → 38,490 customer records queried repeatedly | One key could query at bulk; anomalous token use undetected |
| Mirae Asset mobile web (11/04) | Parameter tampering to view ~3,800 other customers' accounts; noticed the next day | Missing owner check (BOLA/IDOR) |
| Mirae Asset groupware (11/05) | SQL injection exposing 35,255 employees | Dynamic SQL string concatenation |

## 1. Token exchange — RFC 8693

Keep DMZ and partner keys from travelling into internal systems.

- The gateway exchanges an external credential for a **5-minute, single-scope JWT** (RFC 8693)
- Bind the sender certificate thumbprint into the token (`cnf.x5t#S256`, mTLS) or use DPoP
- Internal services trust only the **exchanged short-lived token**, never the original key
- Record exchange history (who changed what scope) in the audit log

## 2. Cardinality rate limiting — Redis HyperLogLog

Per-IP limits fail as soon as the attacker rotates IPs. Look at **how many distinct accounts one token queries per minute**.

```text
Accumulate distinct(account_id) per (token, minute) with a HyperLogLog
distinct(account_id) >= 10  → open the circuit, revoke the token, raise a P1 alert
```

- Normal users touch a handful of accounts per minute; automated bulk queries jump to dozens or hundreds.
- HLL gives approximate cardinality in little memory. Store only the top-risk cases separately if you need exact lists.
- Set the threshold after measuring the normal distribution per service.

## 3. Stop IDOR at the source — per-session HMAC opaque references

- Replace resource IDs exposed to users with **opaque references signed with a per-session HMAC**.
- A middleware validates them in one place: reject on signature or session mismatch before any lookup.
- This structurally prevents the mistake of forgetting a check on a new API.

## 4. SQL injection — block in CI, constrain in the database

- **A Semgrep rule blocks MyBatis `${}` dynamic SQL at the pull request stage.** `${}` is string substitution; `#{}` is binding.
- Set the database `max_join_size` limit to reduce the impact of forced large joins.
- Plant **honey (canary) accounts** in the production database; parameter tampering or SQLi triggers a P1 alert within a second.

## 5. Incident response order

1. Revoke and reissue exposed admin keys and tokens
2. Extract **abnormal cardinality** sessions from the query logs for the period
3. Identify and notify affected accounts; reset passwords and authenticators if needed
4. Apply patterns 1–4 at the gateway and in CI

## References

- Asia Today — Daishin/Mirae 77,000 records: https://www.asiatoday.co.kr/kn/view.php?key=20261123010008969
- Yonhap — Daishin/Mirae: https://www.yna.co.kr/view/AKR20261028068951008
- RFC 8693 — OAuth 2.0 Token Exchange: https://www.rfc-editor.org/rfc/rfc8693

Verified as of 2026-11-26.
