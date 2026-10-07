"""Verify committed release and evidence integrity without installing the SDK."""
from hashlib import sha256
import json
from pathlib import Path
import zipfile

root = Path(__file__).resolve().parent
manifest = json.loads((root / "release/manifest.json").read_text())
artifact = root / "release" / manifest["artifact"]
assert sha256(artifact.read_bytes()).hexdigest().upper() == manifest["sha256"]
for relative, expected in manifest["sourceSha256"].items():
    assert sha256((root / relative).read_bytes()).hexdigest() == expected, relative
for name, expected in manifest["evidenceSha256"].items():
    assert sha256((root / "evidence" / name).read_bytes()).hexdigest() == expected, name
with zipfile.ZipFile(artifact) as archive:
    assert any(name.endswith("-" + manifest["packageId"] + ".dalf") for name in archive.namelist())
    assert not any("daml-script" in name for name in archive.namelist())
    for source in (root / "daml").rglob("*.daml"):
        suffix = "/" + source.relative_to(root / "daml").as_posix()
        names = [name for name in archive.namelist() if name.endswith(suffix)]
        assert len(names) == 1 and archive.read(names[0]) == source.read_bytes(), source
print("ClearRoute release, embedded source and recorded evidence hashes verified.")
