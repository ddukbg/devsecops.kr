# Claude's Riemann Proof — Does It Break RSA or Your Bank?

[한국어](README.md) | [English](README_en.md)

On 20 November 2026, Levent Alpöge, a mathematician at Anthropic, published a proof of the **Riemann Hypothesis** — found with Claude — as a Lean library. A day later the Lean FRO and the Mathlib Initiative issued a joint statement certifying that the statement and the proof are both correct, and Andrew Sutherland (MIT) published an independent verification record.

Short version: **this proof does not break RSA-2048, ECC, or post-quantum cryptography.** What actually changed is that ① results stated "if GRH holds" are now unconditional, and ② an AI agent plus Lean formal verification carried an argument far larger than anyone can hold in their head all the way through kernel checking. What is shrinking is the lifetime of **short legacy keys such as 1024-bit RSA**.

## At a glance

| Item | Detail |
| --- | --- |
| Event | 2026-11-20: Alpöge (Anthropic) released a Lean proof of RH and GRH for Dirichlet L-functions, built with Claude over about six weeks |
| Size | **175,187 files, 17,374,215 lines** (15,531,759 lines of code), 239 MB compressed; no paper, only a 4-page `remark.pdf` |
| Verification | 2026-11-21 joint statement by **Lean FRO · Mathlib**. Sutherland's (MIT) verification record reports every check finished on 2026-11-27 |
| Axioms | The five headline theorems depend only on `propext`, `Classical.choice`, `Quot.sound` |
| Scope | "GRH" here covers **Dirichlet L-functions**; Dedekind zeta, Hecke and automorphic L-functions were not among the checked statements |
| Crypto impact | **None for RSA-2048, ECC, PQC.** Only short legacy keys such as 1024-bit RSA get a shorter shelf life |
| Practical action | No panicked replacement — ① crypto asset inventory ② retire 1024-bit keys ③ crypto-agility ④ accelerate the PQC roadmap |
| Check | [check_legacy_rsa_certs.sh](check_legacy_rsa_certs.sh) — read-only detection of RSA < 2048 and SHA-1 in TLS endpoints, local PEM files and DKIM records |

> The Clay Mathematics Institute still lists the Riemann Hypothesis as **unsolved**. Passing machine verification is not the same as the mathematical community understanding and accepting the proof; participants expect months of work to read the ideas behind 250,000 pages.

## 1. What happened

- The proof was published as a **Lean 4 library**, not a paper. Alpöge wrote that a fully detailed write-up would be unreadably long and left a footnote about a draft of more than 250,000 pages.
- The Lean FRO and Mathlib checked the four criteria from the Xena blog: **the statement is the right one / the library compiles / the code proves that statement / the proof is valid**.
- Sutherland's record extends this with independent kernels: `nanoda` (Rust), `con-leche`, its Rust port `con-ron`, `lean4lean`, and the official `Comparator` all accept the proof. A sandboxed rebuild reproduces the published export byte for byte.
- The shape of the work matters: **an agent produced the artifact, other agents and independent kernels checked it.** It is the first large case where machines confirmed "this is correct" before humans understood the argument.

## 2. Why it read as "encryption is broken" — three questions, not one

| Question | What it is | This proof |
| --- | --- | --- |
| How are primes distributed? | How densely and evenly primes sit on the number line (the error term between π(x) and Li(x)). This is what RH states | **Settled** |
| Is this number prime? | Primality testing. Results conditional on GRH live here | **Conditional → unconditional** |
| Factor this number | Finding p and q in n = p × q. This is what RSA relies on | **Unchanged** |

Headlines about "the secret of the primes" usually confuse the third with the first. Knowing the distribution tells you nothing about the two primes inside your key.

> "The proof leaves RSA exactly as strong as it was last week." — Frank Dickson, Dickson Research (Computerworld, 2026-11-23)

## 3. What actually changed for the general public and for IT

- **General public**: bank, messenger and wallet sessions and certificates are unchanged. RH is a statement about distribution, not a factoring algorithm.
- **IT / mathematics**: results that assumed GRH are now unconditional. The canonical example is Gary Miller's 1976 **deterministic primality test** (Eric Bach computed its cost in 1990). Practice does not change:
  - AKS (2002) already gives unconditional deterministic polynomial-time primality testing.
  - Libraries run the **randomised Miller-Rabin** test a few dozen times; FIPS 186-5 specifies exactly this for RSA prime generation.
- **The real turning point**: not the theorem, but the demonstrated workflow of **AI agent + Lean formal verification** running 17 million lines through kernel checks.

## 4. Security — what is safe, what is shrinking

**Safe now**

| Algorithm | Relies on | Status |
| --- | --- | --- |
| RSA-2048 | integer factorisation | unaffected — considered secure against classical computers |
| ECDSA / ECDH P-256 | elliptic-curve discrete log | unaffected |
| ML-KEM and other PQC | lattice problems (Module-LWE etc.) | unaffected |

**Shrinking (medium term)**

- **1024-bit RSA**: NIST retired it years ago, but such keys still turn up in old website certificates, email security records and device firmware. Cognition estimates breaking one 1024-bit RSA key at roughly **$30 million** in GPU time — a budget line, not an impossibility, for a nation-state.
- **AI-driven acceleration**: AI agents rewrote existing factoring software to run on GPUs at about a tenth of the previous cost. As Dickson puts it, "AI did not find a shortcut; it made the long way cheap."
- **PQC candidates can fail late**: in July 2026 Claude Mythos found a flaw in the mathematics of HAWK, a post-quantum signature candidate studied for years. Hence **crypto-agility**: the ability to swap algorithms by configuration, with rollback.
- **Schedule**: NIST finalised its PQC transition plan on 2026-10-27 — RSA and ECC are to be phased out after 2030 and no longer allowed under NIST standards after 2035. "AI may make that schedule look generous."

> "AI is turning encryption strength into a depreciating asset." — Frank Dickson (Computerworld)

## 5. Four steps for security teams

1. **Crypto asset inventory** — find every key. External certificates first, then email security records (DKIM), then firmware.
2. **Retire 1024-bit** — list RSA < 2048, SHA-1/MD5 signatures and soon-to-expire certificates, and turn them into replacement tickets.
3. **Crypto-agility** — can you change the algorithm by configuration rather than by shipping code, and roll it back? Start with where the TLS group, signature algorithm and KEM are chosen.
4. **Accelerate the PQC roadmap** — data that must stay secret for ten years or more goes first. Treat NIST's 2030/2035 dates as a baseline, not a ceiling.

### Check script

```bash
# 1) TLS endpoints (one host or host:port per line)
curl -sSLO https://raw.githubusercontent.com/ddukbg/devsecops.kr/main/claude-riemann-hypothesis-security/check_legacy_rsa_certs.sh
bash check_legacy_rsa_certs.sh --hosts hosts.txt --csv

# 2) Local certificate directory (PEM/DER: .pem .crt .cer .der)
bash check_legacy_rsa_certs.sh --pem ./certs --json legacy.json

# 3) DKIM public keys (selector:domain)
bash check_legacy_rsa_certs.sh --dkim default:example.com --dkim s1:example.com

# 4) CI gate: exit code 1 when something is found
bash check_legacy_rsa_certs.sh --hosts hosts.txt --strict
```

Findings are reported as `WEAK_KEY` (RSA < 2048), `WEAK_SIG` (SHA-1/MD5), `EXPIRED`/`EXPIRING`, and DKIM `NO_RECORD`/`NO_KEY`. The script never issues, replaces or deletes a certificate and changes no configuration.

## 6. Cross-checked facts

| Fact | Source |
| --- | --- |
| Date, author, size (17M lines, 250,000 pages) | Scientific American (2026-11-20), Nature (2026-11-20), BBC (2026-11-20), Dong-A Science (2026-11-24), Lean 4 Dev analysis |
| Lean FRO · Mathlib statement and its four criteria | Lean community blog joint statement (2026-11-21), Dong-A Science (2026-11-24) |
| 175,187 files / 17,374,215 lines, three axioms, kernels and Comparator, byte-identical sandbox rebuild | math.mit.edu/~drew/grh (Sutherland verification record, updated 2026-11-27) |
| GRH scope limited to Dirichlet L-functions | Sutherland record ("Scope"), Science Monitor (2026-11-21) |
| Primality testing vs factoring, Miller 1976 now unconditional, practice stays Miller-Rabin | Scientific American (2026-11-24), FIPS 186-5 |
| RSA/ECC/PQC unaffected, $30M for 1024-bit, NIST 2030/2035, HAWK | Computerworld (2026-11-23) |

**Limits and unknowns**

- The $30 million figure is an **estimate** scaled from an RSA-896 factorisation; no 1024-bit key has been factored.
- The proof passed machine verification; conceptual understanding and any Clay Institute decision are separate.
- GRH here is for Dirichlet L-functions, not the broadest form of GRH.

## 7. Links

- Scientific American — [What does the Riemann hypothesis proof mean for encryption?](https://www.scientificamerican.com/article/why-solving-the-riemann-hypothesis-wont-break-encryption/) (2026-11-24)
- Computerworld — [Encryption has a new problem: AI is getting better at proving the impossible](https://www.computerworld.com/article/4252348/encryption-has-a-new-problem-ai-is-getting-better-at-proving-the-impossible.html) (2026-11-23)
- Lean community blog — [Lean verification of the Riemann Hypothesis](https://leanprover-community.github.io/blog/posts/riemann-hypothesis/) (2026-11-21)
- MIT — [Verification files for the Lean proof](https://math.mit.edu/~drew/grh/index.html)
- GitHub — [leanprover-community/riemann-hypothesis](https://github.com/leanprover-community/riemann-hypothesis)

---

Verified as of 2026-11-28. Follow your organisation's security policy for replacement decisions.
