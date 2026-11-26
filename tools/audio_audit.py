"""Validate every shipped stream and report duration, loudness and loop-edge health."""
import json
from pathlib import Path
import numpy as np
import soundfile as sf

ROOT = Path(__file__).resolve().parents[1]
catalog = json.loads((ROOT/'art/audio/catalog.json').read_text(encoding='utf-8'))
report = {'effects': {}, 'music': {}, 'ambience': {}}
total_bytes = 0

def inspect(uri):
    global total_bytes
    path = ROOT / uri.removeprefix('res://')
    assert path.is_file(), f'Missing asset: {uri}'
    total_bytes += path.stat().st_size
    peak, energy, count = 0., 0., 0
    with sf.SoundFile(path) as file:
        rate, channels, duration = file.samplerate, file.channels, len(file)/file.samplerate
        assert duration > .01 and channels in [1,2], f'Invalid stream: {uri}'
        # Read the declared length in one decoder call: some Windows Vorbis block readers emit
        # different padding at EOF. The longest score is under 45 MiB as float32 stereo.
        data = file.read(len(file), dtype='float32', always_2d=True)
        assert np.isfinite(data).all(), f'Invalid samples: {uri}'
        peak=float(np.max(np.abs(data)))
        energy=float(np.square(data.astype(np.float64)).sum())
        count=data.size
        first,last=data[0],data[-1]
    assert 1e-5 < peak < .9999, f'Silent or clipped asset: {uri} ({peak})'
    return {'seconds':round(duration,3),'channels':channels,'rate':rate,
            'peak_db':round(20*np.log10(peak),2),'rms_db':round(10*np.log10(energy/count),2),
            'edge_jump':round(float(np.max(np.abs(first-last))),5)}

for name,paths in catalog['effects'].items():
    report['effects'][name]=[inspect(path) for path in paths]
for name,path in catalog['loops'].items():
    report['ambience'][name]=inspect(path)
for name,data in catalog['music'].items():
    report['music'][name]=inspect(data['path'])
    assert report['music'][name]['channels']==2, f'Music must be stereo: {name}'
    assert report['music'][name]['edge_jump'] < .01, f'Loop discontinuity: {name}'
report['total_mib']=round(total_bytes/1048576,2)
target=ROOT/'.tmp/audio-refresh/asset-audit.json'
target.parent.mkdir(parents=True,exist_ok=True)
target.write_text(json.dumps(report,indent=2),encoding='utf-8')
print('AUDIO ASSETS ALL OK:',len(catalog['effects']),'cues,',sum(map(len,catalog['effects'].values())),
      'effect variations,',len(catalog['music']),'stereo scores,',len(catalog['loops']),'ambience beds;',report['total_mib'],'MiB')
for name,stats in report['music'].items(): print(name,stats)
