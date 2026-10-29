"""Materialize a historical source snapshot in a NEW directory; print commands only."""
import argparse
import json
import shlex
import shutil
from pathlib import Path

parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--project',required=True,choices=['spi','i2c','axi_spi'])
parser.add_argument('--build',required=True)
parser.add_argument('--output',required=True,type=Path)
args=parser.parse_args()
root=Path(__file__).resolve().parent
out=args.output.resolve()
if out==root or root in out.parents: parser.error('Replay output must be outside the evidence archive.')
if out.exists(): parser.error('Output must be a new path; nothing will be overwritten.')
src=root/'enhancement/projects'/args.project
snapshot=root/'evidence'/args.project/'builds'/args.build/'source_snapshot'
if not snapshot.is_dir(): parser.error('No preserved source snapshot for this project/build.')
runs=[r for r in json.loads((root/'audit/canonical_runs.json').read_text()) if r['project']==args.project and Path(r['archive_source_snapshot']).parent.name==args.build]
if not runs: parser.error('No canonical historical runs match this project/build.')
dst=out/'projects'/args.project
dst.mkdir(parents=True)
for sub in ('rtl','tb'):
    shutil.copytree(snapshot/sub,dst/sub)
baseline='baseline' if args.project=='axi_spi' else 'baseline_source'
shutil.copytree(src/baseline,dst/baseline)
for name in ('run.py','coverage.hier','cov_hier.cfg','filelist.f','filelist_enhanced.f','filelist_original_rtl.f'):
    if (src/name).is_file():shutil.copy2(src/name,dst/name)
if (src/'scripts').exists():shutil.copytree(src/'scripts',dst/'scripts')
(dst/'build').mkdir(exist_ok=True);(dst/'runs').mkdir(exist_ok=True);(dst/'coverage').mkdir(exist_ok=True);(dst/'reports').mkdir(exist_ok=True)
(out/'scripts').mkdir();(out/'resource_locks').mkdir()
shutil.copy2(root/'enhancement/scripts/resource_gate.py',out/'scripts/resource_gate.py')
script='scripts/run.py' if args.project=='axi_spi' else 'run.py'
commands=[['/usr/bin/python3.11',script,'compile',args.build]]
for r in runs:
    if args.project=='axi_spi':
        commands.append(['/usr/bin/python3.11',script,'sim',args.build,Path(r['log']).parent.name,r['phase'],str(r['random_iterations']),str(r['seed'])])
    else:
        commands.append(['/usr/bin/python3.11',script,args.build,r['phase'],str(r['seed']),str(r['issued_transactions'])])
(out/'replay_commands.json').write_text(json.dumps(dict(cwd=str(dst),commands=commands,status='NOT_EXECUTED'),indent=2)+'\n')
print('Prepared only. No tests have been executed. Run from: '+str(dst))
for command in commands: print(shlex.join(command))
