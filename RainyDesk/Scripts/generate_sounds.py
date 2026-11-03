#!/usr/bin/env python3
"""Original procedural droplets. Standard library only; no downloaded samples."""
import math, random, struct, wave
from pathlib import Path
out = Path(__file__).resolve().parents[1] / 'Resources' / 'Sounds' / 'original'
out.mkdir(parents=True, exist_ok=True)
sr = 44100
for kind, count, base, duration in [('letter',10,1450,.12),('space',3,850,.15),('enter',3,1150,.18),('delete',3,1750,.075)]:
    for j in range(count):
        rng = random.Random(f'{kind}-{j}')
        f = base * rng.uniform(.85,1.15)
        phase = 0
        samples = []
        smooth = 0
        for i in range(int(sr*duration)):
            t = i/sr
            phase += 2*math.pi*(f*(.63+.8*math.exp(-t/0.018)))/sr
            envelope = (1-math.exp(-t/.002))*math.exp(-t/(duration/5))
            smooth = .8*smooth+.2*rng.uniform(-1,1)
            value = math.sin(phase) + .18*math.sin(phase*1.97)*math.exp(-t/.03)+.16*smooth
            if kind == 'enter': value += .14*math.sin(phase*.51)*math.exp(-t/.08)
            fade = min(1,(duration-t)/.01)
            samples.append(value*envelope*fade)
        scale = .60/max(abs(v) for v in samples)
        with wave.open(str(out/f'{kind}_{j}.wav'),'wb') as wav:
            wav.setnchannels(1); wav.setsampwidth(2); wav.setframerate(sr)
            wav.writeframes(b''.join(struct.pack('<h',round(v*scale*32767)) for v in samples))


# Contrasting timbres without the original's large pitch sweep.
root = out.parent
for theme in ['rain', 'pebble', 'wood', 'keyboard', 'marimba']:
    folder = root / theme
    folder.mkdir(parents=True, exist_ok=True)
    for kind, count, pitch, length in [('letter',10,1,1),('space',3,.72,1.1),('enter',3,.88,1.4),('delete',3,1.15,.75)]:
        for j in range(count):
            rng = random.Random(f'{theme}-{kind}-{j}')
            duration = {'rain':.09,'pebble':.095,'wood':.065,'keyboard':.055,'marimba':.22}[theme] * length
            f = {'rain':1100,'pebble':1700,'wood':460,'keyboard':230,'marimba':523.25}[theme] * pitch * rng.uniform(.97,1.03)
            if theme == 'marimba':
                f = 261.626 * 2**([0,2,4,7,9,12,14,16,19,21][j]/12) * pitch
            samples=[]; low=0; smoother=0
            for i in range(int(sr*duration)):
                t=i/sr
                noise=rng.uniform(-1,1)
                low=.55*low+.45*noise
                smoother=.9*smoother+.1*noise
                if theme == 'rain':
                    value=.85*(low-smoother)*math.exp(-t/.012)+.12*math.sin(2*math.pi*f*t)*math.exp(-t/.009)
                elif theme == 'pebble':
                    value=math.sin(2*math.pi*f*t)*math.exp(-t/.012)+.28*low*math.exp(-t/.005)
                elif theme == 'wood':
                    value=(math.sin(2*math.pi*f*t)+.35*math.sin(2*math.pi*f*2.71*t))*math.exp(-t/.010)+.5*low*math.exp(-t/.003)
                elif theme == 'keyboard':
                    value=.85*low*math.exp(-t/.005)+.45*math.sin(2*math.pi*f*t)*math.exp(-t/.007)
                    if t>.013: value+=.25*low*math.exp(-(t-.013)/.004)
                else:
                    value=math.sin(2*math.pi*f*t)*math.exp(-t/.048)+.23*math.sin(2*math.pi*f*4*t)*math.exp(-t/.013)
                envelope=min(1,t/.0015)*min(1,(duration-t)/.009)
                samples.append(value*envelope)
            scale=.60/max(map(abs,samples))
            with wave.open(str(folder/f'{kind}_{j}.wav'),'wb') as wav:
                wav.setnchannels(1);wav.setsampwidth(2);wav.setframerate(sr)
                wav.writeframes(b''.join(struct.pack('<h',round(v*scale*32767)) for v in samples))
# Remove only legacy flat generated filenames; banks above replace them.
for kind in ['letter','space','enter','delete']:
    for j in range(10 if kind=='letter' else 3):
        (root/f'{kind}_{j}.wav').unlink(missing_ok=True)
print('Generated 114 samples across six themes.')
