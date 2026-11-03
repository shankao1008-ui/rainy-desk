#!/usr/bin/env python3
"""Add/update a data-only sound pack, then publish the website using Sites."""
import argparse, hashlib, json, re, shutil, struct, wave
from pathlib import Path
p=argparse.ArgumentParser()
p.add_argument('--site',type=Path,required=True,help='Website dist directory')
p.add_argument('--id',required=True);p.add_argument('--version',type=int,required=True)
p.add_argument('--title',required=True);p.add_argument('--title-en',required=True)
p.add_argument('--detail',default='');p.add_argument('--detail-en',default='')
p.add_argument('--letters',type=Path,required=True);p.add_argument('--other',type=Path,required=True)
a=p.parse_args()
assert re.fullmatch('[a-z][a-z0-9-]{0,47}',a.id) and a.id not in ['rain','pebble','wood','keyboard','marimba','original','voice']
assert 1<=a.version<=1000000
assert all(len(x)<=400 for x in [a.title,a.title_en,a.detail,a.detail_en]) and a.title and a.title_en
root=a.site/'sound-library'; dest=root/'assets';dest.mkdir(parents=True,exist_ok=True)
def add(path):
 data=path.read_bytes();assert 44<=len(data)<=1000000
 with wave.open(str(path)) as w:
  assert (w.getnchannels(),w.getsampwidth(),w.getframerate())==(1,2,44100)
  assert 0<w.getnframes()<=441000
  samples=struct.unpack('<'+'h'*w.getnframes(),w.readframes(w.getnframes()))
  assert max(map(abs,samples))<=19660
 sha=hashlib.sha256(data).hexdigest();name=sha+'.wav';(dest/name).write_bytes(data)
 return {'path':'/sound-library/assets/'+name,'sha256':sha,'bytes':len(data)}
letter=add(a.letters);other=add(a.other)
catalog=root/'catalog.json';doc=json.loads(catalog.read_text()) if catalog.exists() else {'schema':1,'packs':[]}
old=next((x for x in doc['packs'] if x['id']==a.id),None)
assert old is None or a.version>old['version'],'Increase version for an existing pack'
pack={'id':a.id,'version':a.version,'title':a.title,'titleEN':a.title_en,'detail':a.detail,'detailEN':a.detail_en,'mapping':'voice','sounds':{'letter':[letter],'space':[other],'enter':[other],'delete':[other]}}
doc['packs']=[x for x in doc['packs'] if x['id']!=a.id]+[pack]
assert len(doc['packs'])<=50
assert sum(x['bytes'] for pk in doc['packs'] for vals in pk['sounds'].values() for x in vals)<=20000000
catalog.write_text(json.dumps(doc,ensure_ascii=False,indent=2)+'\n')
print('Updated',catalog,'— publish this website to make the sound available to installed apps.')
