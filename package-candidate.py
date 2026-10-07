"""Package only the locally validated DAR; this does not upload anything."""
from datetime import datetime, timezone
from hashlib import sha256
import json
from pathlib import Path
import shutil
import xml.etree.ElementTree as ET
import zipfile

ROOT = Path(__file__).resolve().parent
EVIDENCE = ROOT / 'evidence'
DAR = ROOT / '.daml/dist/clearroute-service-0.1.0.dar'
TEST_DAR = ROOT / 'tests/.daml/dist/clearroute-tests-0.1.0.dar'

def read_json(name):
    return json.loads((EVIDENCE / name).read_text(encoding='utf-8-sig'))

def require(condition, message):
    if not condition:
        raise SystemExit(message)

digest = sha256(DAR.read_bytes()).hexdigest().upper()
unit = ET.parse(EVIDENCE / 'unit-tests.xml').getroot()
ledger = read_json('ledger-results.json')
upgrade = read_json('upgrade-results.json')
inspection = read_json('dar-inspection.json')
count = int(unit.attrib['tests'])
require(count > 0 and unit.attrib['failures'] == unit.attrib['errors'] == '0', 'Unit tests must pass.')
require(ledger['exitCode'] == ledger['failed'] == 0 and ledger['passed'] == ledger['expected'] == count,
        'Ledger integration tests must pass.')
require(digest == read_json('dar-sha256.json')['Hash'] == ledger['darSha256'] == upgrade['baselineSha256'],
        'DAR differs from the tested artifact.')
require(upgrade['optionalFieldUpgrade'] == 'passed' and upgrade['requiredFieldUpgrade'] == 'rejected as expected',
        'Upgrade checks must pass.')
require(not any(p['name'].startswith('daml-script') for p in inspection['packages'].values()),
        'Production DAR must not contain Daml Script.')

source_hashes = {}
for dar_path, source_dir in [(DAR, ROOT / 'daml'), (TEST_DAR, ROOT / 'tests/daml')]:
    with zipfile.ZipFile(dar_path) as archive:
        for source in sorted(source_dir.rglob('*.daml')):
            suffix = '/' + source.relative_to(source_dir).as_posix()
            members = [n for n in archive.namelist() if n.endswith(suffix)]
            require(len(members) == 1 and archive.read(members[0]) == source.read_bytes(),
                    f'Source differs from compiled DAR: {source}')
            source_hashes[source.relative_to(ROOT).as_posix()] = sha256(source.read_bytes()).hexdigest()

with zipfile.ZipFile(DAR) as archive:
    manifest_text = archive.read('META-INF/MANIFEST.MF').decode()
    require('Sdk-Version: 3.4.11' in manifest_text, 'Unexpected compiler version.')
    main_dalf = next(n for n in archive.namelist() if n.endswith(f"-{inspection['main_package_id']}.dalf"))
    main_bytes = archive.read(main_dalf)
with zipfile.ZipFile(TEST_DAR) as archive:
    require(any(n.endswith(f"-{inspection['main_package_id']}.dalf") and archive.read(n) == main_bytes
                for n in archive.namelist()), 'Tests do not depend on this exact production package.')

release = ROOT / 'release'
release.mkdir(exist_ok=True)
destination = release / DAR.name
shutil.copyfile(DAR, destination)
manifest = {
    'status': 'local-validation-passed; hosted Devnet smoke test pending',
    'createdAtUtc': datetime.now(timezone.utc).isoformat(),
    'artifact': DAR.name,
    'sha256': digest,
    'bytes': destination.stat().st_size,
    'packageName': 'clearroute-service',
    'packageVersion': '0.1.0',
    'packageId': inspection['main_package_id'],
    'sdkVersion': '3.4.11',
    'unitScriptsPassed': count,
    'ledgerScriptsPassed': ledger['passed'],
    'testDarSha256': sha256(TEST_DAR.read_bytes()).hexdigest(),
    'evidenceSha256': {p.name: sha256(p.read_bytes()).hexdigest() for p in sorted(EVIDENCE.iterdir()) if p.is_file()},
    'sourceSha256': source_hashes,
    'limitations': [
        'New package family; not an upgrade of the prototype clearroute package.',
        'No NODERS 3.5.19, hosted authentication or cross-participant validation.',
        'No native CC transfers, traffic purchases or external settlement executed.',
        'Application approval, concurrent limits, suspension and global idempotency remain required.',
    ],
}
(release / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
(release / 'SHA256SUMS').write_text(f'{digest.lower()}  {DAR.name}\n')
print(json.dumps({k: manifest[k] for k in ['artifact', 'sha256', 'bytes', 'packageId', 'unitScriptsPassed', 'ledgerScriptsPassed']}, indent=2))
