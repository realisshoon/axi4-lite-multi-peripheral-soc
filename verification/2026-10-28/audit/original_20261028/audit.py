import collections
import csv
import hashlib
import json
import re
from pathlib import Path

ROOT = Path('/home/pedu36/workspace/UVM_ENHANCEMENT_20261019')
OUT = Path(__file__).parent
runs = json.loads((ROOT / 'UVM_PORTFOLIO_PACKAGE/manifests/EXECUTION_MANIFEST.json').read_text())['runs']
rows, issues = [], []
for run in runs:
    path = Path(run['log'])
    data = path.read_bytes()
    text = data.decode(errors='replace')
    lines = text.splitlines()
    project = run['project']
    debug = run['test'] == 'debug_color_test'
    if project in ('spi', 'i2c'):
        marker, count_key, pass_key, fail_key = '[RESULT] issued=', 'checks', 'passes', 'fails'
    elif project == 'axi_spi':
        marker, count_key, pass_key, fail_key = 'AXI_RESULT writes=', 'checks', 'passes', 'fails'
    elif project == 'vga':
        marker = '[DEBUG_SUMMARY] vectors=' if debug else '[ENHANCED_SUMMARY] checked='
        count_key, pass_key, fail_key = ('vectors', None, 'errors') if debug else ('checked', 'pass', 'fail')
    else:
        marker, count_key, pass_key, fail_key = 'RESULT_JSON {', 'checked', 'pass', 'fail'
    matched = [(i + 1, line) for i, line in enumerate(lines) if marker in line]
    if len(matched) != 1:
        issues.append([str(path), 'summary count', len(matched)])
        continue
    lineno, line = matched[0]
    counters = json.loads(line.split('RESULT_JSON ', 1)[1]) if 'RESULT_JSON ' in line else {
        key: int(value) for key, value in re.findall(r'(\w+)=(\d+)(?![\d.])', line)
    }
    checks, failures = counters[count_key], counters[fail_key]
    passes = counters[pass_key] if pass_key else checks - failures
    severity = {}
    for name in ('UVM_ERROR', 'UVM_FATAL'):
        values = re.findall(r'^' + name + r'\s*:\s*(\d+)\s*$', text, re.M)
        severity[name] = int(values[-1]) if values else None
    equality = data == (ROOT / 'UVM_PORTFOLIO_PACKAGE' / run['package_log']).read_bytes()
    actual = (checks, passes, failures, severity['UVM_ERROR'], severity['UVM_FATAL'])
    expected = tuple(run[k] for k in ('check_count', 'pass_count', 'fail_count', 'uvm_error', 'uvm_fatal'))
    if actual != expected or not equality:
        issues.append([str(path), actual, expected, equality])
    completed = counters.get('completed', counters.get('observed', checks))
    issued = counters.get('issued')
    if project == 'axi_spi':
        driver = next(s for s in lines if 'DRIVER_RESULT issued=' in s)
        driver_counts = {k: int(v) for k, v in re.findall(r'(\w+)=(\d+)', driver)}
        issued, completed = driver_counts['issued'], driver_counts['completed']
    # VGA attempts are explicitly metadata-derived, not inferred from checked frames.
    if issued is None:
        issued = run['issued_transactions']
    if (issued, completed) != (run['issued_transactions'], run['completed_transactions']):
        issues.append([str(path), 'issued/completed mismatch', issued, completed])
    rows.append(dict(project=project, test=run['uvm_test_class'], phase=run['phase'], seed=run['seed'],
                     issued=issued, completed=completed, checks=checks, passes=passes, failures=failures,
                     uvm_error=severity['UVM_ERROR'], uvm_fatal=severity['UVM_FATAL'],
                     log=str(path), summary_line=lineno, sha256=hashlib.sha256(data).hexdigest(),
                     package_byte_match=equality, raw_counters=counters))

groups = {}
for row in rows:
    name = row['project'] + ('_debug' if row['test'] == 'debug_color_test' else '')
    groups.setdefault(name, []).append(row)
aggregates = {}
for name, group in groups.items():
    aggregates[name] = dict(runs=len(group), seeds=sorted({r['seed'] for r in group}),
                            test_classes=sorted({r['test'] for r in group}),
                            **{key: sum(r[key] for r in group) for key in ('issued', 'completed', 'checks', 'passes', 'failures')})

manifest_path = ROOT / 'projects/i2c/build/distributed/source_manifest.json'
source_manifest = json.loads(manifest_path.read_text())
source_matches = {name: hashlib.sha256((ROOT / 'projects/i2c' / name).read_bytes()).hexdigest() == digest
                  for name, digest in source_manifest['files'].items()}
if not all(source_matches.values()):
    issues.append(['i2c source mismatch', source_matches])
result = dict(review_date='2026-10-28', scope='Local preserved evidence; no simulator or URG executed; GitHub target ref and current 20-slide PT not yet supplied.',
              logs_checked=len(rows), aggregates=aggregates, i2c_build_source_matches=source_matches,
              issues=issues, runs=rows)
(OUT / 'audit.json').write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
with (OUT / 'verified_runs.csv').open('w', newline='') as f:
    writer = csv.DictWriter(f, fieldnames=list(rows[0]))
    writer.writeheader()
    writer.writerows({**r, 'raw_counters': json.dumps(r['raw_counters'])} for r in rows)
print(json.dumps({k: v for k, v in result.items() if k != 'runs'}, ensure_ascii=False, indent=2))
