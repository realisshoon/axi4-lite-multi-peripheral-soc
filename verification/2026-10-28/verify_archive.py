"""Read-only archive verification. Does not run VCS, URG, or any regression."""
import hashlib
import json
import re
from pathlib import Path

root = Path(__file__).resolve().parent
errors = []
files = 0
for line in (root / 'SHA256SUMS').read_text().splitlines():
    digest, name = line.split('  ', 1)
    path = root / name
    if not path.is_file() or hashlib.sha256(path.read_bytes()).hexdigest() != digest:
        errors.append('file integrity: ' + name)
    files += 1
audited = {r['log']: r for r in json.loads((root / 'audit/original_20261028/audit.json').read_text())['runs']}
runs = json.loads((root / 'audit/canonical_runs.json').read_text())
for row in runs:
    data = (root / row['archive_log']).read_bytes()
    if hashlib.sha256(data).hexdigest() != row['log_sha256'] or row['log_sha256'] != audited[row['log']]['sha256']:
        errors.append('canonical hash: ' + row['archive_log'])
    text = data.decode('utf-8')
    marker = 'AXI_RESULT writes=' if row['project'] == 'axi_spi' else '[RESULT] issued='
    lines = [line for line in text.splitlines() if marker in line]
    if len(lines) != 1:
        errors.append('missing/duplicate summary: ' + row['archive_log']); continue
    counters = {k: int(v) for k, v in re.findall(r'(\w+)=(\d+)(?![\d.])', lines[0])}
    for raw, key in [('checks','check_count'),('passes','pass_count'),('fails','fail_count')]:
        if counters.get(raw) != row[key]: errors.append('counter ' + raw + ': ' + row['archive_log'])
    if row['project'] == 'axi_spi':
        driver = re.search(r'DRIVER_RESULT issued=(\d+) completed=(\d+)', text)
        pair = tuple(map(int, driver.groups())) if driver else None
    else:
        pair = (counters.get('issued'), counters.get('completed'))
    if pair != (row['issued_transactions'], row['completed_transactions']): errors.append('transaction counters: ' + row['archive_log'])
    for name in ('UVM_ERROR','UVM_FATAL'):
        vals = re.findall(r'^'+name+r'\s*:\s*(\d+)\s*$', text, re.M)
        if not vals or int(vals[-1]) != 0: errors.append('severity ' + name + ': ' + row['archive_log'])
for item in json.loads((root/'audit/source_build_checks.json').read_text()):
    path = root/item['snapshot_path']
    if hashlib.sha256(path.read_bytes()).hexdigest() != item['recorded_sha256']:
        errors.append('build source: '+item['snapshot_path'])
print(json.dumps(dict(integrity_files=files,canonical_logs=len(runs),errors=errors,simulation_executed=False),indent=2))
raise SystemExit(bool(errors))
