#!/usr/bin/python3.11
import subprocess,json,sys
from pathlib import Path
root=Path(__file__).resolve().parents[1]
for seed in range(11,21):
 name=f'large_s{seed}'
 p=subprocess.run(['/usr/bin/python3.11','scripts/run.py','sim','fixed_v3',name,'random_large','500',str(seed)],cwd=root,text=True,capture_output=True)
 print(p.stdout.strip(),flush=True)
 if p.returncode or json.loads((root/'runs'/name/'metadata.json').read_text())['result']!='PASS':
  print('STOP: failing seed',seed,flush=True);sys.exit(1)
