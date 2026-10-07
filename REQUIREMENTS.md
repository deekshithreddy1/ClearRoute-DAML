# ClearRoute MVP requirement mapping

Source: the user's detailed build explanation supplied October 7, 2026. The
product is a Canton transaction funding and billing layer with managed funding
and controlled CC top-ups. Initial approvals, invoice generation and settlement
verification may be manual. The current task validates the contract layer;
the entire product must not be declared complete based on its tests.

## Allocation of responsibilities

| Requirement | Contract responsibility | Application / connector requirement |
| --- | --- | --- |
| Signup, company/contact details, login | None; parties are ledger identities | Customer record, authentication and basic role separation |
| Party ID and funding mode | Provider/customer, network and mode on accepted agreement | Verify party ownership/control, participant mapping and designated recipient |
| Funding request and admin approval | Provider issues offer; customer accepts terms | Durable request state, approved limits, named admin, timestamp and notes before offer issuance |
| Managed transaction admission | Managed-only allowances; expiry and positive remaining units checked for demo jobs | Check account approval/status, overdue invoices, aggregate exposure and capacity before every funded submission |
| Transaction logging | Provider-attested `UsageReceipt`, per-allowance usage-reference deduplication | Ingest actual Canton updates with restart-safe offsets; associate customer, deduplicate globally, retain raw evidence |
| Stop funding at limits | Nonpositive recorded allowance blocks subsequent demo jobs; provider can revoke allowance | Serialize/reserve admission capacity before concurrent submissions; block issuance of additional allowances once aggregate limit is reached |
| Suspension/unpaid account | Revoke issued allowances; close agreement to stop future issuance | Disable submission path immediately, reconcile in-flight requests, revoke all outstanding allowances, record reason and notify customer |
| Controlled top-up request/approval | `TopUpReceipt` records completed transfer reference and positive CC amount | Persist request, admin approval, recipient verification, cap, idempotent native transfer, receiver acceptance and verified completion |
| Fifteen-day invoice | Exact 15-day interval; period must have closed; valid nonempty lines and unique charge references | One invoice per customer/cycle, no overlapping/double-billed usage, explicit due-date policy, immutable pricing version and snapshots |
| USD / USDC billing | Amounts are USD-denominated Decimal; payment rail records BankUSD, NativeUSDC or CantonUSDCx | Choose rail, token/issuer, FX/valuation and rounding policy. Record native amount/evidence; do not assume any token called USDC equals settled USD |
| Pricing | Fixed line amounts, pricing-policy and quote references | Define base fee, usage margin/spread, optional minimum and proration for 15-day cycles; examples such as $50 or 5-10% are not approved defaults |
| Mark paid after settlement | Provider-only positive partial/full payment; cannot overpay or reuse a reference on one invoice | Manual authorized evidence check is sufficient for MVP; globally allocate payment references once, record admin and settlement date |
| Dispute | Customer raises nonempty reason, visible to provider; no automatic payment change | Resolve dispute, communicate and audit any commercial adjustment |
| Customer portal/admin dashboard | Customer visibility and provider/customer choice authority | Status, requests, usage, invoices, top-ups, controls, notifications and history |
| Audit trail | Ledger transactions and receipt provenance | Persist transaction history and admin actions, not only active contracts; records can be archived by authorized signatories |

## Deliberate boundaries that need application acceptance tests

1. `SubmitDemoJob` is a sample action and is nonconsuming. It checks capacity but
   does not reserve or debit it. Several submissions can pass before measured
   usage arrives. A backend transaction/lock/reservation is required to satisfy
   the product rule "stop when the limit is hit". This DAR does not impose a
   universal cap on arbitrary customer Canton transactions.
2. Actual measured usage may exceed approved units. The negative remaining balance
   records completed work honestly and prevents later demo jobs. Rejecting that
   evidence would lose billable history. Late usage can be recorded after expiry.
3. Closing an agreement does not cascade to its allowances. Existing allowances
   survive until expiration/revocation; closing alone is insufficient suspension.
   For an account with an unpaid invoice, pause admission first and revoke all
   allowances, including those being issued concurrently. Resume only after review.
4. Reference uniqueness is local to a contract lineage. New allowances and
   invoices can reuse business IDs, and the same payment reference can appear on
   two different invoices. Enforce customer/cycle, charge, native operation and
   payment uniqueness with durable database constraints and an outbox.
5. Provider-issued receipts are attestations. The DAR does not authenticate a
   bank event, execute a token transfer, buy traffic, prove a quoted rate, or prove
   that a receipt refers to real usage. Verify external evidence before issuing
   receipts or exercising `RecordVerifiedPayment`. Customers cannot self-attest.
6. No minimum start date is recorded on agreements. Invoice periods must be fifteen
   days but can predate acceptance, and unpaid historical usage can be invoiced
   after terms expire. The backend must select only eligible, unbilled events
   within the customer's accepted service period.
7. Zero-priced invoice lines are allowed. A zero-total invoice is not eligible for
   a positive payment. Decide the UI's "no payment due" status without inventing
   a payment receipt. Invoice amounts do not implement tax or full accounting.
8. Ledger API authorization is distinct from Daml choice authority. Local tests
   verify the latter and stakeholder visibility, not NODERS token issuance,
   customer login, user rights, topology permissions or network isolation.

## Required remaining acceptance sequence

1. Adapt the backend to the new package/module identities and configure a separate
   Devnet connector. Persist Customer, FundingRequest, TransactionRecord,
   TopUpRecord, Invoice, Payment, PricingPolicy and AdminAction records.
2. Test signup -> request -> admin approval -> customer acceptance -> funded demo
   submission -> verified usage -> invoice -> manually verified payment. Verify
   tenant isolation at both the app API and ledger user-rights boundaries.
3. Test limit reached, two concurrent requests, overdue suspension, revocation,
   retry after restart, uncertain submission, duplicate update, duplicate payment,
   overlapping billing cycle and duplicate top-up request. An unknown result must
   remain unresolved with the same operation ID, never trigger a fresh transfer.
4. Confirm NODERS funding/metering capabilities, then test a small native operation
   using Devnet assets and approved parties. Verify actual delivery/purchase before
   issuing the corresponding ClearRoute receipt. No automatic payment rail is
   required for the MVP; manual verification still needs evidence and an audit log.
5. Demonstrate onboarding, approval, sponsorship or top-up, usage and invoice in
   the UI. Charts, PDF invoices and analytics can follow after those steps work.

Do not claim that a modular DAR or a green Daml suite alone delivers the complete
business workflow. No NODERS configuration, hosted upload, real token transfer,
frontend change or backend Devnet deployment is performed by this review.
