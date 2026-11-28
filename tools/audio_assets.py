"""Build the shipped audio from the GDD's music and Kenney CC0 foley.

Sources are cached outside the shipped game in .tmp/audio-refresh/sources. See art/audio/CREDITS.md.
Requires numpy, scipy, soundfile and ffmpeg. No synthesis or downloads happen while playing.
Run: python tools/audio_assets.py --sources .tmp/audio-refresh/sources
"""
from __future__ import annotations
import argparse
import hashlib
import io
import json
from pathlib import Path
import subprocess
import zipfile
import numpy as np
from scipy import signal
import soundfile as sf

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'art/audio'
RATE = 44100
RNG = np.random.default_rng(58104)
CATALOG = {'version': 2, 'effects': {}, 'loops': {}, 'music': {}, 'sources': {}}
PACKS = {}
SOURCE_FILES = {}

def mono(x):
    return x.mean(axis=1) if x.ndim == 2 else x

def resample(x, old_rate):
    return signal.resample_poly(x, RATE, int(old_rate)).astype(np.float32) if old_rate != RATE else x

def sample(pack, name, speed=1.0):
    key = pack, name
    if key not in SOURCE_FILES:
        member = next(n for n in PACKS[pack].namelist() if n.endswith('/' + name + '.ogg'))
        data, rate = sf.read(io.BytesIO(PACKS[pack].read(member)), dtype='float32')
        SOURCE_FILES[key] = resample(mono(data), rate)
    x = SOURCE_FILES[key]
    return signal.resample(x, max(1, int(len(x) / speed))).astype(np.float32) if speed != 1 else x.copy()

def mix(*layers, seconds=None):
    # Layers: (audio, gain, offset_seconds); leave tails intact.
    n = int(seconds * RATE) if seconds else max(int(start * RATE) + len(x) for x, _, start in layers)
    out = np.zeros(n, dtype=np.float32)
    for x, gain, start in layers:
        at = int(start * RATE)
        count = min(len(x), n - at)
        if count > 0:
            out[at:at+count] += x[:count] * gain
    return out

def envelope(x, fade_in=.004, fade_out=.025):
    x = x.copy()
    a, b = min(len(x)//2, int(fade_in*RATE)), min(len(x)//2, int(fade_out*RATE))
    if a: x[:a] *= np.linspace(0, 1, a)
    if b: x[-b:] *= np.linspace(1, 0, b)
    return x

def tone(sec, f0, f1=None, decay=3, harmonics=(1., .22, .08)):
    t = np.arange(int(sec*RATE), dtype=np.float32) / RATE
    f1 = f0 if f1 is None else f1
    phase = np.cumsum(np.geomspace(f0, f1, len(t))) * 2*np.pi/RATE
    x = sum(a*np.sin((i+1)*phase) for i,a in enumerate(harmonics))
    return envelope((x*np.exp(-decay*t/sec)).astype(np.float32))

def noise(sec, low=50, high=2500, decay=2):
    x = RNG.standard_normal(int(sec*RATE)).astype(np.float32)
    sos = signal.butter(2, [low, high], fs=RATE, btype='bandpass', output='sos')
    x = signal.sosfilt(sos, x).astype(np.float32)
    x *= np.exp(-np.linspace(0, decay, len(x)))
    return envelope(x)

def reverb(x, wet=.15):
    return mix((x, 1, 0), (x, wet, .079), (x, wet*.65, .151), (x, wet*.4, .263))

def finish(x, peak=.72):
    x = np.nan_to_num(x).astype(np.float32)
    x -= x.mean(axis=0)
    x = envelope(x)
    maximum = max(.00001, float(np.max(np.abs(x))))
    return np.clip(x * peak / maximum, -.95, .95)

def write_ogg(path, audio):
    # libsndfile's Windows Vorbis writer can exhaust its small thread stack on long buffers.
    # ffmpeg's encoder is also the common path used for the imported music.
    channels=1 if audio.ndim==1 else audio.shape[1]
    subprocess.run(['ffmpeg','-hide_banner','-loglevel','error','-y','-f','f32le','-ar',str(RATE),
                    '-ac',str(channels),'-i','pipe:0','-c:a','libvorbis','-q:a','4',str(path)],
                   input=np.asarray(audio,dtype='<f4').tobytes(),check=True)

def effect(name, versions, loop=False):
    paths = []
    for i, x in enumerate(versions):
        p = OUT / 'sfx' / f'{name}_{i+1:02}.wav'
        sf.write(p, finish(x), RATE, subtype='PCM_16')
        paths.append('res://' + p.relative_to(ROOT).as_posix())
    CATALOG['effects'][name] = paths
    if loop:
        CATALOG.setdefault('channels', []).append(name)

def juggernaut_slam():
    # One offline mix: a deep thud, breaking stone and a short earth-rumble tail.
    body = mix((sample('scifi', 'lowFrequency_explosion_000', .8), .7, 0),
               (sample('impact', 'impactMining_000', .85), .65, 0),
               (sample('impact', 'impactMining_001', .95), .4, .08),
               (tone(1.2, 47, 26, 5, (1., .45, .18)), .38, 0), seconds=1.65)
    effect('boss_slam', [reverb(body, .15)])

def juggernaut_charge():
    # Broad-band rushing wind and heavy footfalls remain audible on small speakers.
    rush = mix((noise(1.12, 160, 5200, .7), .6, 0),
               (tone(1.12, 130, 55, 1.8, (1., .5, .25)), .25, 0),
               *[(sample('impact', 'impactMining_000', 1.15), .28, at)
                 for at in [0., .23, .46, .69, .92]], seconds=1.25)
    effect('boss_charge', [envelope(rush, .025, .15)])

def chainwarden():
    effect('chain_ready', [mix((sample('impact', 'impactMetal_light_000'), .5, 0),
                               (sample('impact', 'impactMetal_light_001'), .4, .12), seconds=.45)])
    effect('chain_sweep', [mix((noise(.4, 350, 6500, 2), .6, 0),
                               (sample('impact', 'impactMetal_heavy_000', 1.2), .45, .12))])
    effect('chain_throw', [mix((noise(.5, 700, 8000, 2), .6, 0),
                               *[(sample('impact', 'impactMetal_light_000', 1.5), .22, i*.065) for i in range(5)])])
    effect('chain_catch', [mix((sample('impact', 'impactMetal_heavy_001'), .6, 0),
                               (noise(.5, 250, 3000, 4), .25, .04))])

def boss_skills():
    # Dedicated skill cues for Bio-Cannon, Burrower, Earthshaker, Phantom and Voltspire.
    effect('boss_acid_charge', [mix((sample('scifi', 'slime_000', 1.15), .55, 0),
                                    (tone(.48, 170, 520, 1.2, (1., .35, .15)), .38, 0),
                                    (noise(.48, 600, 3800, 1.4), .24, 0), seconds=.52)])
    effect('boss_acid_lob', [mix((sample('scifi', 'slime_001', .95), .68, 0),
                                 (tone(.36, 210, 78, 4.5, (1., .4)), .5, 0),
                                 (noise(.32, 300, 2800, 3.2), .3, .03), seconds=.48)])
    effect('boss_acid_splash', [reverb(mix((sample('scifi', 'slime_000', .72), .72, 0),
                                           (sample('impact', 'impactSoft_heavy_000', .85), .45, 0),
                                           (noise(.62, 1100, 7200, 2.8), .42, .02), seconds=.72), .12)])
    effect('boss_spine_erupt', [reverb(mix((sample('impact', 'impactMining_001', 1.1), .65, 0),
                                           (sample('impact', 'impactMining_000', 1.35), .5, .07),
                                           (sample('impact', 'impactMining_002', 1.25), .45, .14),
                                           (noise(.55, 450, 5200, 3.2), .38, 0),
                                           (tone(.45, 140, 52, 4.5, (1., .45)), .32, 0), seconds=.7), .14)])
    effect('boss_quake_fissure', [reverb(mix((sample('scifi', 'lowFrequency_explosion_000', 1.05), .62, 0),
                                             (sample('impact', 'impactMining_002', .78), .62, 0),
                                             (tone(.58, 68, 30, 4.2, (1., .5, .2)), .45, 0),
                                             (noise(.5, 180, 2600, 3.5), .35, .02), seconds=.72), .16)])
    effect('boss_tremor_ring', [reverb(mix((sample('scifi', 'lowFrequency_explosion_000', .68), .68, 0),
                                           (tone(1.05, 86, 32, 2.2, (1., .45, .22)), .52, 0),
                                           (noise(1.0, 90, 1400, 1.8), .45, .04), seconds=1.18), .22)])
    effect('boss_phantom_slash', [reverb(mix((noise(.32, 1400, 9200, 4.2), .68, 0),
                                             (tone(.28, 1250, 420, 5.5, (1., .32, .14)), .45, 0),
                                             (sample('rpg', 'drawKnife1', 1.35), .45, .02), seconds=.42), .18)])
    effect('boss_mirage_dash', [reverb(mix((sample('scifi', 'forceField_001', 1.55), .58, 0),
                                           (noise(.45, 900, 7600, 2.6), .58, 0),
                                           (tone(.4, 680, 240, 3.8, (1., .28)), .38, .03), seconds=.58), .2)])
    effect('boss_volt_charge', [mix((sample('scifi', 'forceField_000', 1.35), .5, 0),
                                    (tone(.58, 220, 880, .8, (1., .45, .25, .12)), .42, 0),
                                    (noise(.58, 1800, 8800, 1.5), .28, 0), seconds=.64)])
    effect('boss_lightning_strike', [reverb(mix((noise(.14, 1600, 11000, 5.5), .85, 0),
                                                (sample('scifi', 'explosionCrunch_000', 1.15), .65, .01),
                                                (tone(.65, 190, 38, 3.6, (1., .5, .25)), .48, .02),
                                                (noise(.78, 110, 1800, 2.8), .45, .05), seconds=.92), .22)])
    effect('boss_arc_beam', [reverb(mix((sample('scifi', 'laserLarge_000', .85), .58, 0),
                                        (tone(1.1, 310, 260, .6, (1., .55, .35, .2, .12)), .46, 0),
                                        (noise(1.1, 1400, 8500, .9), .34, 0), seconds=1.22), .14)])

def originals():
    # Organic breaths and resonant impacts, rather than the previous square-wave placeholder sounds.
    for name, base in [('growl', 82), ('hurt', 145), ('my_hurt', 105), ('enemy_die', 120), ('death', 92)]:
        effect(name, [reverb(mix((tone(.42, base+i*8, base*.67, 3, (1,.65,.3,.15)), .7, 0),
                                (noise(.4, 90, 1200, 5), .65, 0))) for i in range(3)])
    for i, base in enumerate([42, 57, 92, 36, 49, 128, 40]):
        breath = noise(1.6, 60+i*11, 1300+i*90, 2)
        rumble = tone(1.6, base*1.45, base*.7, 1.8, (1,.7,.4,.24,.1))
        pulse = .7 + .3*np.sin(np.arange(len(breath))/RATE*(7+i*.5)*2*np.pi)
        effect('boss_roar_'+str(i), [reverb(mix((breath*pulse, .7, 0), (rumble, 1, .05)), .25)])
    effect('boss_roar', [reverb(mix((tone(1.6, 65, 32, 2), 1, 0), (noise(1.6, 60, 1200), .8, 0)), .3)])
    effect('boss_arrival', [reverb(mix((tone(2.4, 45, 30, 4), 1, 0), (noise(1.4, 50, 2200), .5, 0)), .25)])
    effect('boss_die', [reverb(mix((tone(2.5, 95, 28, 4), .7, 0), (noise(2.1, 80, 1400, 5), .8, .1)), .25)])
    effect('boss_warn', [mix((tone(1., 180, 620, .1, (1,.12)), .45, 0), (noise(1., 300, 3500, .1), .16, 0), seconds=1.)])
    effect('boss_swing', [mix((noise(.35, 60, 1800, 3), .6, 0), (tone(.35, 90, 40, 7), .5, .06))])
    for name, source, speed in [('boss_surface','explosionCrunch_002',.75),
                              ('boss_burrow','slime_001',.55), ('boss_barrage','slime_000',.8),
                              ('boss_stagger','impactMetal_001',.65), ('boss_ambush','forceField_001',1.4),
                              ('boss_cloak','forceField_000',.7),
                              ('boss_summon','spaceEngineLow_000',1.4)]:
        effect(name, [envelope(sample('scifi',source,speed))])
    juggernaut_slam()
    juggernaut_charge()
    chainwarden()
    boss_skills()
    effect('bow', [mix((tone(.35, 180+i*13, decay=12, harmonics=(1,.5,.26,.12)), .75, 0),
                      (sample('rpg','cloth'+str(i+1)), .2, 0), (noise(.12,1500,7500,7), .12, .015)) for i in range(3)])
    effect('dusk_horn', [reverb(mix((tone(2.5, 155, 210, .8, (1,.32,.16)), .5, 0), (tone(2.5, 158, 213, .8), .4, 0)), .3)])
    effect('night_gong', [reverb(mix((sample('impact','impactBell_heavy_000',.4), .7, 0), (tone(2.1, 49, decay=6), .35, 0)), .25)])
    radio = mix((noise(.7, 500, 6500, 3), .2, 0), (tone(.12, 1200, decay=12), .15, .08), (tone(.12, 900, decay=12), .12, .23))
    for name in ['dawn', 'radio_static', 'start']:
        effect(name, [radio])
    effect('downed', [mix((sample('rpg','dropLeather',.75), .6, 0), (tone(1., 210, 100, 4, (1,.1)), .3, .08))])
    effect('bleed_tick', [tone(.09, 740, decay=9, harmonics=(1,.06))])
    effect('heartbeat', [mix((tone(.12, 60, 43, 8), 1, 0), (tone(.12, 72, 46, 8), .6, .19), seconds=.9)], True)
    for name, frequencies in [('revive', [440, 554, 660]), ('radio_online', [392, 523, 784]), ('part_found', [660, 880, 1320]),
                              ('part_install',[330,440]), ('heal',[400,600]), ('flask',[350,560]), ('heal_zone',[440,660])]:
        effect(name, [reverb(mix(*[(tone(.45,f,decay=6,harmonics=(1,.06)), .22, i*.09) for i,f in enumerate(frequencies)]), .12)])
    for name, freq in [('breach', 530), ('base_alarm', 450)]:
        effect(name, [mix(*[(tone(.16,freq,decay=1,harmonics=(1,.25)), .4, i*.24) for i in range(3)])])
    effect('poison', [mix((sample('scifi','slime_001'), .6, 0), (noise(1.2, 200, 2800, 4), .4, 0))])
    effect('haste', [mix((noise(.55,700,7000,3), .2, 0), (tone(.5,300,800,4,(1,.1)), .16, 0))])
    effect('win', [tone(.7,523,decay=4,harmonics=(1,.1))])
    effect('lose', [mix((radio,.5,0),(tone(1.3,65,35,5),.4,0))])

def foley():
    mapping = {
      'hit': ('impact','impactPunch_medium_00',3), 'hit_boss':('impact','impactMetal_heavy_00',3),
      'chop':('impact','impactWood_medium_00',3), 'mine':('impact','impactMining_00',3),
      'mine_metal':('impact','impactMetal_light_00',3), 'herb':('rpg','cloth',3),
      'wood_break':('impact','impactPlank_medium_00',3), 'crumble':('impact','impactMining_00',3),
      'metal_break':('impact','impactPlate_heavy_00',3), 'door_hit':('impact','impactWood_heavy_00',3),
      'door_crack':('impact','impactPlank_medium_00',3), 'gen_hit':('scifi','impactMetal_00',3),
      'build':('impact','impactMetal_medium_00',2), 'repair':('impact','impactMetal_light_00',3),
      'wrecker_atk':('impact','impactPunch_heavy_00',3), 'arrow_hit':('impact','impactWood_light_00',3),
      'tower_zap':('scifi','laserSmall_00',3), 'tower_break':('scifi','explosionCrunch_00',2),
      'explode':('scifi','lowFrequency_explosion_00',2), 'spit':('scifi','slime_00',2),
      'ui_click':('interface','click_00',3), 'ui_hover':('interface','select_00',2),
      'ui_open':('interface','open_00',2), 'ui_close':('interface','close_00',2),
      'equip':('rpg','beltHandle',2), 'item_move':('interface','drop_00',2),
      'pickup':('interface','pluck_00',2), 'item_drop':('rpg','bookPlace',3),
      'drop_spawn':('interface','pluck_00',2), 'empty_bow':('rpg','metalClick',1),
      'craft_done':('interface','confirmation_00',2), 'ping':('interface','question_00',2),
      'vote':('interface','toggle_00',2), 'trap_set':('rpg','clothBelt',1), 'snare':('rpg','beltHandle',2),
    }
    for cue,(pack,prefix,count) in mapping.items():
        zero_based = pack in ['impact','scifi']
        versions = []
        for i in range(count):
            suffix = str(i if zero_based else i+1)
            if cue in ['trap_set','empty_bow']: suffix = ''
            x = sample(pack,prefix+suffix)
            if cue in ['hit_boss','wrecker_atk','gen_hit','tower_break']:
                x = mix((x,.8,0),(tone(.2,65,38,7),.2,0))
            versions.append(x)
        effect(cue, versions)
    for material,prefix in [('grass','grass'),('stone','concrete'),('wood','wood'),('sand','snow')]:
        effect('step_'+material,[sample('impact','footstep_'+prefix+'_00'+str(i)) for i in range(4)])
    effect('step_metal',[mix((sample('impact','footstep_concrete_00'+str(i)), .6, 0),
                            (sample('impact','impactMetal_light_00'+str(i)), .2, .01)) for i in range(3)])
    effect('step_water',[mix((sample('impact','footstep_grass_00'+str(i)), .5, 0), (sample('scifi','slime_00'+str(i%2),1.7), .3,0)) for i in range(3)])
    effect('step',[sample('impact','footstep_grass_000')])
    for cue, source in [('swing','knifeSlice'),('attack_basic','knifeSlice'),('attack_hammer','chop'),
                        ('attack_stun_maul','chop'),('attack_stone_spear','drawKnife1'),
                        ('attack_long_spear','drawKnife2'),('attack_titanium_blade','knifeSlice2')]:
        x = sample('rpg',source,.85 if cue == 'attack_stun_maul' else 1.)
        effect(cue,[mix((x,.8,0),(noise(.2,400,4500,7),.15,0))])
    effect('chest_open',[mix((sample('rpg','metalLatch'), .8, 0),(sample('rpg','creak1'),.5,.08))])
    effect('chest_close',[mix((sample('rpg','doorClose_1'), .5, 0),(sample('rpg','metalClick'),.3,.12))])
    effect('chest_unlock',[mix((sample('rpg','metalClick'),.5,0),(sample('rpg','metalLatch'),.7,.16))])
    effect('entry',[sample('scifi','doorClose_001')])
    for cue, pack, source, interval in [('repair_loop','impact','impactMetal_light_000',.31),
          ('build_loop','impact','impactWood_medium_000',.35),('craft_loop','rpg','metalPot1',.39),
          ('unlock_loop','rpg','metalClick',.23),('revive_loop','rpg','cloth1',.48),
          ('radio_loop','scifi','computerNoise_000',.6)]:
        x=sample(pack,source)
        effect(cue,[mix(*[(x,.5,i*interval) for i in range(3)], seconds=max(1.,len(x)/RATE+interval*2))],True)

def periodic_noise(sec, high):
    n=int(sec*RATE)
    f=np.fft.rfftfreq(n,1/RATE)
    spectrum=(RNG.standard_normal(len(f))+1j*RNG.standard_normal(len(f)))
    spectrum *= np.exp(-f/high)/np.maximum(f,25)**.6
    spectrum[f<25]=0
    x=np.fft.irfft(spectrum,n).astype(np.float32)
    return x/max(float(np.max(np.abs(x))),1e-7)

def ambience():
    sec=24
    t=np.arange(sec*RATE)/RATE
    wind=periodic_noise(sec,650)
    for name in ['amb_day','amb_night','amb_coast','amb_cave','amb_swamp','amb_base','amb_station','helicopter']:
        x=wind*.2
        if name=='amb_day':
            for at in [2,2.2,6.9,13,13.15,19.7]:
                x=mix((x,1,0),(tone(.12,2450,3300,3,(1,.1)),.04,at),seconds=sec)
        elif name=='amb_night':
            for at in np.arange(1,sec-1,.79):
                x=mix((x,1,0),(tone(.09,3700,3550,5,(1,.2)),.018,float(at)),seconds=sec)
        elif name=='amb_coast':
            x=periodic_noise(sec,3500)*(.25+.25*np.sin(t*2*np.pi/8))
        elif name=='amb_cave':
            x=wind*.12
            for at in [1.5,5.7,11,17.9,21]:
                drop=reverb(tone(.06,850,450,8,(1,.2)),.5)
                x=mix((x,1,0),(drop,.045,at),seconds=sec)
        elif name=='amb_swamp':
            x=periodic_noise(sec,2200)*.12
            for at in [2,5,10,15,19,22]:
                x=mix((x,1,0),(tone(.2,130,80,6,(1,.4,.2)),.05,at),seconds=sec)
        elif name in ['amb_base','amb_station']:
            x=wind*.08+.1*np.sin(2*np.pi*50*t)+.045*np.sin(2*np.pi*100*t)
            x*=.8+.2*np.sin(t*2*np.pi*(8 if name=='amb_base' else .5))
        elif name=='helicopter':
            rotor=(.5+.5*np.sin(2*np.pi*12*t))**4
            x=periodic_noise(sec,1600)*rotor*.8+.22*np.sin(2*np.pi*48*t)*rotor
        p=OUT/'ambience'/f'{name}.ogg'
        write_ogg(p,finish(x,.45))
        CATALOG['loops'][name]='res://'+p.relative_to(ROOT).as_posix()

def music(cache, refresh=False):
    boss_member='Colossal Boss Battle Theme/Blackmoor Colossus Loop.wav'
    with zipfile.ZipFile(cache/'boss.zip') as archive:
        boss=cache/'boss_loop.wav'
        if not boss.exists(): boss.write_bytes(archive.read(boss_member))
    tracks={'menu':'menu.mp3','day':'day.wav','night_early':'night_early.wav','night_late':'night_late.wav',
            'boss':'boss_loop.wav','final':'final.wav','loss':'loss.mp3'}
    for name,file in tracks.items():
        src=cache/file
        out=OUT/'music'/f'{name}.ogg'
        # A short taper on both edges avoids a click when the imported loop wraps.
        if not out.exists() or refresh:
            duration=float(subprocess.check_output(['ffprobe','-v','error','-show_entries','format=duration',
                                                    '-of','default=nw=1:nk=1',str(src)],text=True).strip())
            subprocess.run(['ffmpeg','-hide_banner','-loglevel','error','-y','-i',str(src),'-vn','-af',
               f'loudnorm=I=-20:TP=-2:LRA=10,afade=t=in:d=0.012,afade=t=out:st={max(0,duration-.018):.6f}:d=0.018',
               '-ar','44100','-ac','2','-c:a','libvorbis','-q:a','4',str(out)],check=True)
        CATALOG['music'][name]={'path':'res://'+out.relative_to(ROOT).as_posix(),'loop':name!='loss'}
    # A short original hopeful resolution for MUS-08, with layered sustained strings and soft piano.
    sec=24.; score=np.zeros(int(sec*RATE),dtype=np.float32)
    for bar,chord in enumerate([[50,57,62,65],[46,53,58,62],[41,48,57,60],[48,55,60,64],[50,57,62,66]]):
        for k,note in enumerate(chord):
            f=440*2**((note-69)/12)
            string=tone(5.4,f,decay=.8,harmonics=(1,.3,.16,.09,.04))
            string=envelope(string,.6,1.2)
            score=mix((score,1,0),(string,.09,bar*4.1),seconds=sec)
            piano=tone(2.,f*2,decay=6,harmonics=(1,.24,.07))
            score=mix((score,1,0),(piano,.07,bar*4.1+k*.25),seconds=sec)
    score=finish(reverb(score,.28),.4)
    score=envelope(score,.5,3.)
    stereo=np.stack([score,np.roll(score,317)],axis=1)
    write_ogg(OUT/'music/win.ogg',stereo)
    CATALOG['music']['win']={'path':'res://art/audio/music/win.ogg','loop':False}

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--sources',type=Path,default=ROOT/'.tmp/audio-refresh/sources')
    parser.add_argument('--refresh-music',action='store_true',help='rebuild cached score conversions')
    parser.add_argument('--juggernaut-slam',action='store_true',help='rebuild only the ground-slam effect')
    parser.add_argument('--juggernaut-skills',action='store_true',help='rebuild only the slam and charge effects')
    parser.add_argument('--chainwarden',action='store_true',help='rebuild and register only the four chain skill effects')
    args=parser.parse_args()
    for sub in ['sfx','ambience','music']: (OUT/sub).mkdir(parents=True,exist_ok=True)
    for pack in ['rpg','impact','interface','scifi']: PACKS[pack]=zipfile.ZipFile(args.sources/(pack+'.zip'))
    if args.chainwarden:
        chainwarden()
        path = OUT/'catalog.json'
        existing = json.loads(path.read_text(encoding='utf-8'))
        existing['effects'].update(CATALOG['effects'])
        path.write_text(json.dumps(existing,indent=2)+'\n',encoding='utf-8')
        print('CHAINWARDEN AUDIO OK: ready, sweep, throw and catch')
        return
    if args.juggernaut_slam or args.juggernaut_skills:
        juggernaut_slam()
        if args.juggernaut_skills:
            juggernaut_charge()
        print('JUGGERNAUT AUDIO OK: ground impact' + (' and charge' if args.juggernaut_skills else ''))
        return
    print('Building material and interaction foley...', flush=True)
    foley()
    print('Building creature, radio and warning cues...', flush=True)
    originals()
    print('Building island ambience...', flush=True)
    ambience()
    print('Converting the GDD soundtrack...', flush=True)
    music(args.sources,args.refresh_music)
    for f in sorted(args.sources.iterdir()):
        if f.suffix in ['.zip','.mp3','.wav'] and f.name!='boss_loop.wav':
            CATALOG['sources'][f.name]={'sha256':hashlib.sha256(f.read_bytes()).hexdigest()}
    (OUT/'catalog.json').write_text(json.dumps(CATALOG,indent=2)+'\n',encoding='utf-8')
    print(f"AUDIO BUILD OK: {len(CATALOG['effects'])} effect cues, {len(CATALOG['loops'])} ambience beds, {len(CATALOG['music'])} scores")

if __name__=='__main__': main()
