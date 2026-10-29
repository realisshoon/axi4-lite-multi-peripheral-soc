#!/usr/bin/python3.11
"""Limit this enhancement's EDA processes to two slots. Never controls other users."""
import fcntl,os,subprocess,sys,time
from pathlib import Path
root=Path(__file__).resolve().parents[1]; args=sys.argv[1:]
if args and args[0]=='--':args=args[1:]
if not args:raise SystemExit('usage: resource_gate.py -- vcs|simv|urg ...')
slots=[open(root/'resource_locks'/f'eda_{i}.lock','a+') for i in range(2)]
while True:
 for f in slots:
  try:fcntl.flock(f,fcntl.LOCK_EX|fcntl.LOCK_NB)
  except BlockingIOError:continue
  print(f'[RESOURCE_GATE] slot={f.name} pid={os.getpid()} command={args[0]}',flush=True)
  try:raise SystemExit(subprocess.call(args))
  finally:fcntl.flock(f,fcntl.LOCK_UN)
 time.sleep(0.5)
