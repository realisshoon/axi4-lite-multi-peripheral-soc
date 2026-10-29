#!/usr/bin/python3.11
import subprocess,json,sys
from pathlib import Path
root=Path(__file__).resolve().parents[1]
steps=[('final_smoke_s1','smoke',0,1),('final_directed_s1','directed',0,1),('final_small_s3','random_small',50,3),('final_intermediate_s4','random_1000',500,4)]+[(f'final_large_s{s}','random_large',500,s)for s in range(11,21)]
for name,mode,n,seed in steps:
 cmd=['/usr/bin/python3.11','scripts/run.py','sim','fixed_v4',name,mode,str(n),str(seed)]
 if mode=='directed':cmd+=['wave']
 p=subprocess.run(cmd,cwd=root,text=True,capture_output=True);print(p.stdout.strip(),flush=True)
 if p.returncode or json.loads((root/'runs'/name/'metadata.json').read_text())['result']!='PASS':print('STOP',name,flush=True);sys.exit(1)
