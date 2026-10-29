#!/usr/bin/python3.11
import sys,subprocess,json,re,datetime,os,shutil,hashlib
from pathlib import Path
root=Path(__file__).resolve().parents[1];os.chdir(root)
gate=['/usr/bin/python3.11',str(root.parents[1]/'scripts/resource_gate.py'),'--']
def run(cmd,log,cwd=None):
 with open(log,'w')as f:return subprocess.call(gate+list(map(str,cmd)),stdout=f,stderr=subprocess.STDOUT,cwd=cwd)
def now():return datetime.datetime.now().astimezone().isoformat()
if sys.argv[1]=='compile':
 name=sys.argv[2]; build=root/'runs'/name;build.mkdir(exist_ok=True)
 snapshot=build/'source_snapshot';snapshot.mkdir(exist_ok=True)
 for source_dir in ['tb','rtl']:
  if not(snapshot/source_dir).exists():shutil.copytree(root/source_dir,snapshot/source_dir)
 (snapshot/'filelist_enhanced.f').write_text((root/'filelist_enhanced.f').read_text())
 (snapshot/'SHA256SUMS').write_text(''.join(hashlib.sha256(p.read_bytes()).hexdigest()+'  '+str(p.relative_to(snapshot))+'\n' for p in sorted(snapshot.rglob('*'))if p.is_file() and p.name!='SHA256SUMS'))
 cmd=['vcs','-full64','-sverilog','-ntb_opts','uvm-1.2','-timescale=1ns/1ps','-debug_access+all','-assert','svaext','-cm','line+cond+fsm+tgl+branch+assert','-cm_hier','cov_hier.cfg','-cm_dir',build/'build.vdb','-f','filelist_original_rtl.f' if name.startswith('original_') else 'filelist_enhanced.f','-top','tb_top','-o',build/'simv','-Mdir='+str(build/'csrc'),'-l',build/'compile.log']
 code=run(cmd,build/'compile_console.log');print('compile',name,'exit',code);sys.exit(code)
if sys.argv[1]=='sim':
 build,name,mode,n,seed=sys.argv[2:7]; wave='wave'in sys.argv[7:]
 directory=root/'runs'/name;directory.mkdir(exist_ok=False);started=now()
 cmd=[root/'runs'/build/'simv',f'+MODE={mode}',f'+N={n}',f'+ntb_random_seed={seed}','+UVM_VERBOSITY=UVM_LOW','-cm','line+cond+fsm+tgl+branch+assert','-cm_dir',root/'runs'/build/'build.vdb','-cm_name',name,'-l',directory/'simulation.log']
 if wave:cmd+=['+WAVE']
 code=run(cmd,directory/'console.log',directory);s=(directory/'simulation.log').read_text()if(directory/'simulation.log').exists()else''
 def val(p,default=0):
  m=re.search(p,s);return int(m.group(1))if m else default
 summary=re.search(r'AXI_RESULT (.+)',s);fields={}
 if summary:
  for k,v in re.findall(r'(\w+)=([0-9.]+)',summary[1]):fields[k]=float(v)if'.'in v else int(v)
 console=(directory/'console.log').read_text();a=re.search(r'ASSERT_RESULT attempts=(\d+) failures=(\d+)',console)
 result={'project':'axi_spi','phase':mode,'test':'enhanced_test','seed':int(seed),'random_iterations':int(n),'issued_transactions':val(r'DRIVER_RESULT issued=(\d+)'),'completed_transactions':val(r'DRIVER_RESULT issued=\d+ completed=(\d+)'),'check_count':fields.get('checks',0),'pass_count':fields.get('passes',0),'fail_count':fields.get('fails',0),'uvm_error':val(r'UVM_ERROR\s*:\s*(\d+)'),'uvm_fatal':val(r'UVM_FATAL\s*:\s*(\d+)'),'assert_attempts':int(a[1])if a else 0,'assert_failures':int(a[2])if a else 0,'timeout':'TIMEOUT'in s,'expected_failure':name.startswith('before_'),'result':'PASS' if summary and fields.get('fails')==0 and val(r'UVM_ERROR\s*:\s*(\d+)')==0 and val(r'UVM_FATAL\s*:\s*(\d+)')==0 and code==0 and a and int(a[2])==0 else'FAIL','exit_code':code,'log':str(directory/'simulation.log'),'wave':str(directory/'trace.vcd')if wave else None,'coverage_db':str(root/'runs'/build/'build.vdb'),'coverage_test':name,'started':started,'finished':now(),'counters':fields}
 (directory/'metadata.json').write_text(json.dumps(result,indent=2));print(json.dumps(result))
if sys.argv[1]=='urg':
 name=sys.argv[2]; dbs=sys.argv[3:];directory=root/'reports'/name;directory.mkdir(exist_ok=False)
 cmd=['urg','-full64','-dir']+dbs+['-report',str(directory/'urg_report'),'-format','both','-show','ratios','-group','ratio','-log',str(directory/'urg.log')]
 code=run(cmd,directory/'console.log');print('urg',name,'exit',code);sys.exit(code)
