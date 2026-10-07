# ClearRoute service contracts

This package is the ledger record layer of ClearRoute's transaction funding and
billing MVP. It supports managed service agreements, measured usage, fifteen-day
invoices, manual settlement attestations, and native-operation receipts. Customer
onboarding, administrator approval, admission control and native funding execution
belong to the application and its connectors; uploading this DAR does not supply
those capabilities.

The product requirements supplied on October 7, 2026 are mapped in
[REQUIREMENTS.md](REQUIREMENTS.md). Read that mapping before configuring Devnet.
Validation results are in [TEST-REPORT.md](TEST-REPORT.md); the reviewed candidate
and SHA-256 manifest are in [release/](release/).

## Package and module layout

Package name: `clearroute-service`; version: `0.1.0`; SDK: `3.4.11`; Daml-LF: `2.2`.
The production DAR contains no Daml Script dependency or test modules.

| Module | Responsibility / templates |
| --- | --- |
| `ClearRoute.Types` | Network, service mode, settlement rail, terms, invoice lines, pure validators |
| `ClearRoute.Offer` | `ServiceOffer`: accept, decline, withdraw |
| `ClearRoute.Agreement` | `ServiceAgreement`: issue allowances/invoices, close |
| `ClearRoute.Allowance` | `UsageAllowance`: authorize demo jobs, record usage, revoke |
| `ClearRoute.UsageReceipt` | `UsageReceipt` |
| `ClearRoute.Demo` | `DemoJob`, `DemoCompletion` |
| `ClearRoute.Invoice` | `Invoice`: partial/full payments and dispute initiation |
| `ClearRoute.PaymentReceipt` | `PaymentReceipt` |
| `ClearRoute.Dispute` | `InvoiceDispute` |
| `ClearRoute.FundingReceipt` | `FundingReceipt`: attests a verified native traffic purchase |
| `ClearRoute.TopUpReceipt` | `TopUpReceipt`: attests a verified native CC transfer |

These are modules within one deployable package, not eleven independently
upgradeable packages. This keeps the initial release and its dependencies small.
Keep these module/template names stable after the first deployment. Shared types
and dependencies also participate in upgrade compatibility.

## Changes from the prototype

- Split the former `ClearRoute.Service` module by responsibility.
- Enforce distinct provider/customer parties and nonempty parent identifiers on
  allowances, jobs, invoices and receipts where those fields exist.
- Reject empty or duplicated usage/payment history references on direct creation.
- Require an invoice's zero/nonzero paid amount to agree with the absence/presence
  of payment references. Actual payment authenticity remains a provider trust boundary.
- Pin production and test compilation to the same installed SDK. The Windows
  runner directly invokes that compiler, avoiding ambient assistant SDK overrides.
- Extend twelve prototype scripts to cover invalid input, authority, privacy,
  exact boundaries, decimal precision, rollback, replay and complete workflows.

## Reproduce validation

Run from this directory with Daml SDK 3.4.11 installed:

```powershell
.\test-windows.ps1
.\test-upgrade-windows.ps1
```

`test-windows.ps1` compiles and validates the production DAR, builds the separate
test DAR with a data dependency on that artifact, runs all scripts, and saves
JUnit, coverage and the tested DAR's SHA-256 under `evidence/`.
`test-upgrade-windows.ps1` creates disposable 0.1.1 fixtures: an optional receipt
field must compile against the baseline, and a required field must be rejected.
Neither fixture is a release artifact. This is a compiler compatibility check,
not a deployed cross-version migration test.

Run the Ledger API integration stage in a separate terminal:

```powershell
.\start-sandbox-windows.ps1 -JavaDirectory <path-to-OpenJDK>
# Wait for "Canton sandbox is ready", then in another terminal:
.\test-ledger-windows.ps1 -JavaDirectory <path-to-OpenJDK>
```

The sandbox is disposable, in memory, and uses loopback ports 16865-16870. Stop
its terminal with Ctrl+C after the test. Do not point the test suite at a shared
node: it allocates many fixture parties and changes ledger time. Tests use network
enum values including MainNet strictly as contract data, never as destinations.
The runner only targets `127.0.0.1:16865` and saves each script result.
After successful gates, run `python package-candidate.py` to verify source and
artifact consistency and copy the candidate plus manifest into `release/`.

On this machine an existing Temurin 17.0.19 archive was extracted to the ignored
workspace directory `.tools/jdk-17.0.19+10`; that is the scripts' default. No host
Java configuration was changed. Oracle Java 17 initially produced `JCE cannot
authenticate the provider BC` on transaction submission; this is a documented
[sandbox runtime issue](https://archived.docs.digitalasset.com/build/3.4/component-howtos/application-development/dpm-sandbox.html).

Coverage reports measure template creation and choice exercise, not every branch,
all possible inputs, concurrency load, or proof of absence of bugs. The repeated
metering test checks 64 serial updates, not production throughput.

## Upgrade strategy

DAR contents are immutable, but Canton supports new compatible package versions.
Splitting source files improves reviewability; it does not itself confer
upgradeability. See Digital Asset's
[Smart Contract Upgrade documentation](https://get-docs.digitalasset.com/build/3.4/sdlc-howtos/smart-contracts/upgrade/smart-contract-upgrades.html).

The prototype uses `clearroute:ClearRoute.Service:*`. Moving those templates
changes their identities, so this is a **new package family** named
`clearroute-service`, not an in-place upgrade of `clearroute-0.1.0`.
Any existing prototype contracts remain prototype contracts. Complete/close them
under the old package, or design an explicitly authorized migration separately.
Do not disable upgrade checks to force the modular package over the old one.

After first deployment, retain the exact baseline DAR and manifest, increment
the version for every release, and compile with `upgrades: <baseline.dar>` (or
`--upgrades`). Check both data compatibility and business behavior. Renaming a
module, changing signatories or changing field types is not a routine refactor
of a deployed identity. Run old/new contract integration tests before upgrades.

## Backend template mapping

The existing LocalNet adapters in both copies of `ClearRoute-app` still target
`#clearroute:ClearRoute.Service:*`, and their setup commands reference the old DAR.
They were not repointed to Devnet by this contract-only change. Do not run their
existing setup command expecting it to configure this release.

The new command identifiers are `#clearroute-service:<module>:<template>`, using
the table above. For example:

```text
#clearroute-service:ClearRoute.Offer:ServiceOffer
#clearroute-service:ClearRoute.Agreement:ServiceAgreement
#clearroute-service:ClearRoute.Allowance:UsageAllowance
#clearroute-service:ClearRoute.Demo:DemoJob
#clearroute-service:ClearRoute.Demo:DemoCompletion
```

Returned created events contain concrete package IDs. Verify the package against
the release manifest and match the appropriate module/template, rather than
searching for `:ClearRoute.Service:`. Do not reuse prototype contract IDs with the
new identifiers. Regenerate typed bindings or update the adapter's explicit map,
then run its component and integration gates as a separate application change.

## NODERS configuration handoff

The supplied portal text identifies participant `hackcanton-devnet-3`, Ledger API
3.5.19, no customer parties, and zero DAR uploads by this account. These are
user-supplied observations; this review did not access the NODERS account.

1. Review [REQUIREMENTS.md](REQUIREMENTS.md), especially admission control and
   native operation evidence. Confirm NODERS supports this DAR's LF version and
   dependencies; local SDK 3.4.11 tests do not prove hosted 3.5.19 compatibility.
2. Use the release candidate named `clearroute-service-0.1.0.dar`, with its
   manifest/hash. Never upload the test DAR, upgrade fixtures, or the prototype
   DAR by mistake. The upload remains a user-controlled action.
3. Create one provider service party and two distinct test customer parties
   (e.g. ClearRouteProvider, Atlas, Nova) using the portal's namespace mechanism.
   Store the complete returned IDs; do not construct them from the displayed
   prefix. Three parties leave capacity within the supplied twenty-party quota.
4. Obtain the supported authentication flow. The displayed JWT subject is a
   ledger user ID, not an access token. Keep credentials in backend secret
   configuration. Confirm separate `actAs`/`readAs` rights for provider and each
   customer; a single all-party token must not be exposed to customer browsers.
5. Configure the backend's Devnet adapter with the supplied HTTPS Ledger endpoint
   `https://ledger-api-json.participant.hackcanton-01.devnet.naas.noders.services`
   or TLS gRPC endpoint
   `ledger-api-grpc.participant.hackcanton-01.devnet.naas.noders.services:443`.
   Discover the actual synchronizer ID; do not invent a migration ID from `-`.
6. Run a small authenticated workflow: offer, customer acceptance, allowance,
   demo job, completion, measured usage. Save update IDs, offsets and contract IDs.
   Verify that Nova cannot read Atlas's contracts or act as Atlas. The 15-day
   invoice boundary is tested locally; do not try to change hosted ledger time.
7. Before native funding, obtain NODERS' supported wallet/token-transfer and
   traffic-purchase/metering access. The supplied participant endpoints alone do
   not establish those capabilities or identify the treasury wallet. Confirm
   receiver authorization/acceptance and native completion evidence.

Creating a party does not create a funded wallet. A CC transfer to a party also
does not create an independent traffic balance: Global Synchronizer traffic is
shared at participant level. See
[Synchronizer traffic fees](https://docs.sync.global/deployment/traffic.html).
Keep customer CC holdings, provider treasury inventory, participant traffic,
application allowance units, and invoiced USD amounts as separate quantities.
# ClearRoute contracts: current release

This repository contains only the extracted ClearRoute contract project.
Production modules are in **daml/ClearRoute/**; tests are in
**tests/daml/ClearRoute/**. The uploadable artifact and exact package identity
are in **release/**. See **release/manifest.json** and **release/SHA256SUMS**.

The October 7 rename changes Daml module identifiers and therefore the package
ID. Discard earlier upload instructions/checksums. This is a fresh first
deployment candidate, not an automatic upgrade of any previously uploaded DAR.
The app's contract mappings and example profile were updated to this release.

On Windows, run test-windows.ps1, start-sandbox-windows.ps1 in another terminal,
test-ledger-windows.ps1, and test-upgrade-windows.ps1. Supply -JavaDirectory when
the SDK needs your installed JDK. The sandbox is disposable and uses ports
16865–16870; it never connects to NODERS.

Branch flow: sprint/01-clearroute-contracts → dev → main.
App deployment instructions live in the separate ClearRoute app repository.
