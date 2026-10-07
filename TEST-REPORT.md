# Contract validation report — October 7, 2026

Rebuilt after renaming production and test modules to ClearRoute.*. The new
artifact passed all 31 interpreter tests, all 31 sandbox Ledger API tests and
both upgrade compatibility checks on October 7. release/manifest.json binds the
exact source and evidence to the DAR. App typechecks, 83 backend tests,
38 frontend tests and container restart smoke tests also passed separately.

**Result: local contract validation passed. Hosted Devnet and complete MVP
acceptance remain pending.** No NODERS upload or account configuration was made.

| Gate | Result | Evidence |
| --- | --- | --- |
| Production build, SDK 3.4.11 | Passed | `release/manifest.json` |
| DAR validation | Valid, 30 packages including standard library dependencies | `evidence/dar-inspection.json` |
| Daml Script interpreter | 31 passed, 0 failed | `evidence/unit-tests.xml` |
| Template coverage | 11/11 created | `evidence/coverage.txt` |
| Choice coverage | 23/23 exercised: 12 business choices plus 11 Archive choices | `evidence/coverage.txt` |
| Canton sandbox Ledger API | 31 passed, 0 failed, exit 0 | `evidence/ledger-results.json`, `evidence/ledger-tests.log` |
| Compatible optional-field upgrade | Accepted by compiler | `evidence/upgrade-results.json` |
| Incompatible required-field upgrade | Rejected by compiler | `evidence/upgrade-results.json` |
| Artifact/source consistency | Candidate matches tested hash; production and test sources match embedded source; test DAR contains exact production DALF | `package-candidate.py`, `release/manifest.json` |

The candidate is [clearroute-service-0.1.0.dar](release/clearroute-service-0.1.0.dar).
Its SHA-256 is
`b027bc5df95f0f424bc8084ae9a6f401ee61b25634824b2483405b43ef91b50f`.
Its main package ID is
`a5d7aff449a19279433832cda0a58adc9632f832a15ce05d427a305bc4b012f5`.

## What was exercised

- Customer acceptance and two-party agreement creation; wrong-party rejection;
  decline, withdrawal, closure and consumption replay.
- Valid/invalid terms, distinct parties, nonempty parent references, allowance
  minimum/maximum, expiry equality, wrong service mode and revocation.
- Demo job creation/completion, tenant visibility, failed-choice rollback and
  the deliberate non-reserving behavior of job submission.
- Zero, exact exhaustion, overshoot, late/future/negative usage, usage-reference
  deduplication, stale IDs, batch rollback and 64 consecutive metering updates.
- Fifteen-day invoice boundaries, early issuance, due dates, malformed/duplicate
  lines, malformed direct invoice state, exact decimal amounts, partial/full
  payments, duplicate/empty evidence references, zero/negative amounts and overpayment.
- All real-payment rail enum values; MainNet simulated-payment rejection.
  These are policy/record tests, not actual bank or token settlements.
- Dispute authority/privacy; native receipt guards and visibility; archive
  authority and the need to retain historical updates beyond active contracts.
- Complete service -> allowance -> job -> completion -> usage -> invoice ->
  payment -> revocation/closure workflows across all four network enum values.

## Integration environment and limitations

Integration used an isolated in-memory Canton sandbox from SDK 3.4.11 on
`127.0.0.1:16865`, static time, and Temurin OpenJDK 17.0.19. The sandbox was stopped
after validation. The first Oracle Java attempt failed with a cryptography
provider authentication error; the successful OpenJDK run is the reported gate.
No machine-wide Java settings were changed and no dependency was downloaded.

This validates actual local Ledger API command execution, contract authorization,
queries, failures and multi-step transactions. It does not validate Splice
traffic purchase, CC holdings/transfers, a multi-participant topology, NODERS
Ledger API 3.5.19, HTTP adapter payloads, hosted JWT/user-right configuration,
frontend behavior, database durability, concurrent admission limits, or native
settlement. Application tests were run separately as described above.
Choice coverage is not branch coverage or a security proof.

## Release implications

The refactor intentionally uses a new package family, `clearroute-service`.
Earlier prototype adapters/contracts are not migrated. This release uses
`ClearRoute.*` modules and a new package ID; the hosted app mappings were updated.
Follow the new identifier table and staged Devnet checklist in [README.md](README.md).

[REQUIREMENTS.md](REQUIREMENTS.md) maps the user's MVP to contract versus
application responsibilities. Critical application gates are administrator
approval, verified party mapping, capacity reservation, suspension/revocation,
global usage/payment/top-up deduplication and evidence-backed manual settlement.
The current contracts support that design but do not implement those backend
controls by themselves. They are service records, not a treasury or token engine.
