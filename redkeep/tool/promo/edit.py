"""Builds the promo video from the recordings, rendered graphics and audio.

Run from redkeep/:  python3 tool/promo/edit.py [wide|tall|both] [--scenes s04,s05] [--draft]
Everything is read from and written to docs/play-store/promo-video (work/ and
out/ are git-ignored).
"""
import json
import math
import os
import subprocess
import sys

ROOT = 'docs/play-store/promo-video'
REC = f'{ROOT}/work/rec'
GFX = f'{ROOT}/work/gfx'
AUD = f'{ROOT}/audio'
TMP = f'{ROOT}/work/scenes'
OUT = f'{ROOT}/out'
FPS = 60
XF = 0.4  # crossfade between scenes, seconds

FORMATS = {
    # canvas, screen rect (x, y, w, h)
    'wide': ((1920, 1080), (1173, 75, 414, 930)),
    'tall': ((1080, 1920), (219, 410, 642, 1440)),
}
DEV = (1080, 2424)  # recording size


def clip(src, a, b, speed=1.0):
    return {'src': src, 'a': a, 'b': b, 'speed': speed}


def zoom(t0, t1, scale, x, y, ease=0.6):
    """Push in on device point (x, y) of the screen between t0 and t1."""
    return {'t0': t0, 't1': t1, 'scale': scale, 'x': x, 'y': y, 'ease': ease}


def blur(x, y, w, h, t0=0, t1=999):
    """Blur a device-space box of the screen (privacy)."""
    return {'x': x, 'y': y, 'w': w, 'h': h, 't0': t0, 't1': t1}


# Each scene: graphics sequence or app clips, caption, voice line, offsets.
SCENES = [
    dict(id='s01', seq='intro', vo='VO-01', vo_at=0.6, sfx=[('SFX-03', 0.5, -14)]),
    dict(id='s02', seq='title', vo='VO-02', vo_at=0.4, sfx=[('SFX-01', 0.1, -12)]),
    dict(id='s03', cap='s03', vo='VO-03', vo_at=0.3,
         clips=[clip('s03_onboarding', 1.5, 3.7), clip('s03_onboarding', 6.7, 8.0),
                clip('s03b_cover', 3.3, 9.6), clip('s03_onboarding', 10.3, 12.2)],
         sfx=[('SFX-01', 2.2, -10), ('SFX-03', 4.3, -14)]),
    dict(id='s04', cap='s04', vo='VO-04', vo_at=0.3,
         clips=[clip('s04_diary_day', 1.5, 4.8), clip('s04b_dark', 1.3, 4.8)],
         wipe=3.3, sfx=[('SFX-02', 2.2, -16), ('SFX-11', 3.6, -10)]),
    dict(id='s05', cap='s05', vo='VO-05', vo_at=0.3,
         clips=[clip('s05_mood', 3.7, 6.7), clip('s05_mood', 13.4, 15.4)],
         sfx=[('SFX-04', 1.25, -8), ('SFX-04', 3.1, -10)]),
    dict(id='s06', cap='s06', vo='VO-06', vo_at=0.3,
         clips=[clip('s06_write', 0.2, 9.0)], hold=True,
         sfx=[('SFX-03', 2.4, -14), ('SFX-04', 8.0, -10)]),
    dict(id='s07', cap='s07', vo='VO-07', vo_at=0.3,
         clips=[clip('s07_photos', 0.3, 5.0), clip('s07_photos', 9.0, 13.4)],
         sfx=[('SFX-05', 1.1, -10), ('SFX-05', 7.4, -12)]),
    dict(id='s08', cap='s08', vo='VO-08', vo_at=0.3,
         clips=[clip('s08_raven', 0.6, 6.08)], hold=True,
         zooms=[zoom(1.0, 4.4, 2.3, 830, 330)],
         sfx=[('SFX-06', 1.6, -8)]),
    dict(id='s09', cap='s09', vo='VO-09', vo_at=0.3,
         clips=[clip('s09_calendar', 0.2, 10.8)],
         sfx=[('SFX-14', 0.9, -12), ('SFX-14', 7.7, -12)]),
    dict(id='s10', cap='s10', vo='VO-10', vo_at=0.3,
         clips=[clip('s10_search', 1.2, 7.8)], hold=True,
         sfx=[('SFX-02', 0.5, -16), ('SFX-13', 5.3, -14)]),
    dict(id='s11', cap='s11', vo='VO-11', vo_at=0.3,
         clips=[clip('s11_notes', 0.4, 5.4, 1.4), clip('s11_notes', 6.4, 8.0),
                clip('s11_notes', 16.5, 18.7)],
         sfx=[('SFX-02', 3.6, -16), ('SFX-04', 5.4, -10)]),
    dict(id='s12', cap='s12', vo='VO-12', vo_at=0.3,
         clips=[clip('s12_editor', 4.0, 10.8, 1.5), clip('s12_editor', 0.0, 2.4)],
         zooms=[zoom(4.6, 6.8, 2.0, 400, 830)],
         sfx=[('SFX-10', 5.7, -6)]),
    dict(id='s13', cap='s13', vo='VO-13', vo_at=0.3,
         clips=[clip('s13_background', 1.8, 6.9, 1.7), clip('s13_background', 19.6, 21.6, 1.3),
                clip('s13_background', 28.8, 30.0), clip('s13b_applied', 0.6, 3.4)],
         sfx=[('SFX-04', 0.9, -12), ('SFX-02', 4.6, -16), ('SFX-13', 6.4, -14)]),
    dict(id='s14', cap='s14', vo='VO-14', vo_at=0.3,
         clips=[clip('voice', 0.0, 8.0)], hold=True, sfx=[]),
    dict(id='s15', seq='maester', vo='VO-15', vo_at=0.4, sfx=[('SFX-07', 0.2, -10)]),
    dict(id='s17', cap='s17', vo='VO-17', vo_at=0.3,
         clips=[clip('s17_ask', 2.0, 4.6, 1.3), clip('s17b_attach', 1.2, 2.9),
                clip('s17_ask', 5.2, 6.6), clip('s17_ask', 13.4, 16.0)],
         zooms=[zoom(5.6, 7.6, 1.5, 540, 1500)],
         sfx=[('SFX-07', 3.9, -12), ('SFX-13', 5.6, -14)]),
    dict(id='s16', cap='s16', vo='VO-16', vo_at=0.3,
         clips=[clip('s16_title', 0.2, 2.0), clip('s16_title', 10.4, 12.6),
                clip('s16_tags', 4.0, 6.0), clip('s16_tags', 13.0, 14.2),
                clip('s16_tags', 26.0, 28.3, 1.2)],
         sfx=[('SFX-13', 2.2, -14), ('SFX-13', 6.4, -14)]),
    dict(id='s19', cap='s19', vo='VO-19', vo_at=0.3,
         clips=[clip('s19_settings', 1.0, 15.18, 1.5)],
         sfx=[('SFX-13', 4.4, -14)]),
    dict(id='s20', cap='s20', vo='VO-20', vo_at=0.3,
         clips=[clip('s20_wall', 1.0, 7.4)], sfx=[('SFX-02', 0.2, -16)]),
    dict(id='s21', cap='s21', vo='VO-21', vo_at=0.3,
         clips=[clip('s21_moods', 0.8, 4.4), clip('s21_moods', 8.6, 12.8)],
         sfx=[('SFX-04', 3.7, -10)]),
    dict(id='s22', cap='s22', vo='VO-22', vo_at=0.3,
         clips=[clip('s22_title', 1.0, 2.8), clip('s22b_stamp', 0.8, 2.8),
                clip('s22_title', 8.4, 11.6, 1.4), clip('s22c_lists', 0.6, 4.0, 1.4)],
         zooms=[zoom(1.8, 3.9, 1.6, 540, 1000)],
         sfx=[('SFX-08', 2.3, -4), ('SFX-10', 4.4, -10), ('SFX-10', 5.0, -10), ('SFX-04', 7.6, -10)]),
    dict(id='s23', cap='s23', vo='VO-23', vo_at=0.3,
         clips=[clip('s23_spin', 1.2, 6.2)], sfx=[('SFX-09', 0.6, -10)]),
    dict(id='s24', cap='s24', vo='VO-24', vo_at=0.3,
         clips=[clip('s24_appearance', 2.4, 6.8, 1.5), clip('s24_appearance', 9.2, 12.6, 1.5),
                clip('s24_appearance', 14.0, 15.5), clip('s24_appearance', 25.8, 28.6)],
         sfx=[('SFX-11', 0.8, -14), ('SFX-04', 3.3, -10), ('SFX-04', 4.1, -10)]),
    dict(id='s25', cap='s25', vo='VO-25', vo_at=0.3,
         clips=[clip('s25_widgets', 0.0, 8.0)], hold=True,
         zooms=[zoom(0.4, 3.0, 1.9, 540, 700)],
         sfx=[('SFX-04', 4.6, -8)]),
    dict(id='s26', cap='s26', vo='VO-26', vo_at=0.3,
         clips=[clip('s26_backup', 0.2, 3.2), clip('s26_backup', 3.2, 12.0, 2.0),
                clip('s26b_done', 0.0, 1.1)], hold=True,
         blurs=[blur(240, 760, 600, 80, 0, 1.6), blur(170, 262, 620, 56, 1.2, 99),
                blur(150, 2300, 780, 90, 1.2, 99)],
         sfx=[('SFX-12', 0.5, -10), ('SFX-13', 7.6, -10)]),
    dict(id='s27', seq='closing', vo='VO-27', vo_at=0.5, sfx=[('SFX-01', 0.2, -14)]),
    dict(id='s28', seq='signature', vo='VO-28', vo_at=0.5, sfx=[('SFX-03', 0.3, -12)]),
]

SEQ_LEN = {'intro': 6.6, 'title': 3.6, 'maester': 4.4, 'closing': 7.0, 'signature': 4.6}


def run(cmd):
    r = subprocess.run(cmd, capture_output=True, text=True)
    if r.returncode:
        print(' '.join(cmd)[:2000])
        print(r.stderr[-4000:])
        sys.exit(1)


def probe(path):
    r = subprocess.run(['ffprobe', '-v', 'error', '-show_entries', 'format=duration',
                        '-of', 'csv=p=0', path], capture_output=True, text=True)
    return float(r.stdout.strip())


def vo_len(scene):
    p = f"{AUD}/{scene['vo']}.mp3"
    return probe(p) if os.path.exists(p) else 0


def clips_len(scene):
    return sum((c['b'] - c['a']) / c['speed'] for c in scene.get('clips', []))


def scene_len(scene):
    need = scene['vo_at'] + vo_len(scene) + 0.75
    if 'seq' in scene:
        return max(SEQ_LEN[scene['seq']], need)
    return max(need, 3.0) if scene.get('hold') else max(need, min(clips_len(scene), need + 1.6))


def src_path(name):
    return f'{GFX}/voice.mp4' if name == 'voice' else f'{REC}/{name}.mp4'


def ease_expr(p):
    # smoothstep of p (an expression clamped to 0..1)
    return f'(({p})*({p})*(3-2*({p})))'


def build_app_scene(scene, fmt, dur, draft):
    (cw, ch), (sx, sy, sw, sh) = FORMATS[fmt]
    out = f"{TMP}/{fmt}/{scene['id']}.mp4"
    inputs, parts = [], []
    for i, c in enumerate(scene['clips']):
        inputs += ['-i', src_path(c['src'])]
        parts.append(
            f"[{i}:v]trim={c['a']}:{c['b']},setpts=(PTS-STARTPTS)/{c['speed']},"
            f"fps={FPS},scale={sw}:{sh}:flags=lanczos,setsar=1[c{i}]")
    n = len(scene['clips'])
    # Join clips: a quick cross dissolve, or a diagonal wipe for day → night.
    chain = 'c0'
    offset = (scene['clips'][0]['b'] - scene['clips'][0]['a']) / scene['clips'][0]['speed']
    for i in range(1, n):
        c = scene['clips'][i]
        d = 0.5 if scene.get('wipe') else 0.18
        kind = 'diagbl' if scene.get('wipe') else 'fade'
        parts.append(f"[{chain}][c{i}]xfade=transition={kind}:duration={d}:offset={offset - d:.3f}[j{i}]")
        chain = f'j{i}'
        offset += (c['b'] - c['a']) / c['speed'] - d
    # Hold the last frame to fill the scene, then cut to length.
    parts.append(f"[{chain}]tpad=stop_mode=clone:stop_duration={dur + 2},trim=0:{dur},setpts=PTS-STARTPTS[scr]")
    # Privacy blurs, in device space scaled to the screen.
    k = sw / DEV[0]
    cur = 'scr'
    for j, b in enumerate(scene.get('blurs', [])):
        x, y, w, h = [round(v * k) for v in (b['x'], b['y'], b['w'], b['h'])]
        parts.append(f"[{cur}]split[bA{j}][bB{j}];[bB{j}]crop={w}:{h}:{x}:{y},gblur=sigma=7:steps=3[bC{j}];"
                     f"[bA{j}][bC{j}]overlay={x}:{y}:enable='between(t,{b['t0']},{b['t1']})'[bl{j}]")
        cur = f'bl{j}'
    base = len(scene['clips'])
    inputs += ['-loop', '1', '-i', f'{GFX}/{fmt}/bg.png',
               '-loop', '1', '-i', f'{GFX}/{fmt}/phone.png',
               '-loop', '1', '-i', f"{GFX}/{fmt}/cap_{scene['cap']}.png"]
    bg, ph, cap = base, base + 1, base + 2
    parts.append(f"[{bg}:v]fps={FPS},trim=0:{dur}[bg]")
    parts.append(f"[bg][{cur}]overlay={sx}:{sy}[s1]")
    parts.append(f"[{ph}:v]fps={FPS},trim=0:{dur}[ph]")
    parts.append(f"[s1][ph]overlay=0:0[s2]")
    # Caption eases in, and steps aside while the camera pushes in.
    hide = ''
    if scene.get('zooms'):
        env = '+'.join(
            f"min(clip((T-{z['t0']})/0.35,0,1),clip(({z['t1']}-T)/0.35,0,1))" for z in scene['zooms'])
        hide = f",geq=r='r(X,Y)':g='g(X,Y)':b='b(X,Y)':a='alpha(X,Y)*(1-clip({env},0,1))'"
    parts.append(f"[{cap}:v]fps={FPS},trim=0:{dur},format=rgba,fade=t=in:st=0.15:d=0.5:alpha=1{hide}[cp]")
    rise = "'40*(1-clip((t-0.15)/0.6,0,1))'"
    parts.append(f"[s2][cp]overlay=x=0:y={rise}[s3]")
    last = 's3'
    zooms = scene.get('zooms', [])
    if zooms:
        # Push in on screen points. zoompan on a 2x frame keeps the motion
        # smooth (it rounds the window to whole input pixels).
        t = f'(on/{FPS})'
        terms, fx_terms, fy_terms = [], [], []
        for z in zooms:
            e, t0, t1 = z['ease'], z['t0'], z['t1']
            k_ = (f"min({ease_expr(f'clip(({t}-{t0})/{e},0,1)')},"
                  f"{ease_expr(f'clip(({t1}-{t})/{e},0,1)')})")
            terms.append(f"{z['scale'] - 1}*{k_}")
            fx_terms.append((sx + z['x'] * sw / DEV[0], k_))
            fy_terms.append((sy + z['y'] * sh / DEV[1], k_))
        zexpr = '1+' + '+'.join(terms)
        # The window's centre travels from the canvas centre to the point.
        cx = f'2*({cw / 2}' + ''.join(f'+({fx - cw / 2})*{k_}' for fx, k_ in fx_terms) + ')'
        cy = f'2*({ch / 2}' + ''.join(f'+({fy - ch / 2})*{k_}' for fy, k_ in fy_terms) + ')'
        parts.append(
            f"[{last}]scale={cw * 2}:{ch * 2}:flags=lanczos,"
            f"zoompan=z='{zexpr}':x='clip({cx}-iw/zoom/2,0,iw-iw/zoom)':"
            f"y='clip({cy}-ih/zoom/2,0,ih-ih/zoom)':d=1:s={cw}x{ch}:fps={FPS}[s4]")
        last = 's4'
    parts.append(f"[{last}]format=yuv420p[v]")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    enc = ['-c:v', 'libx264', '-preset', 'veryfast' if draft else 'slow', '-crf', '24' if draft else '16']
    run(['ffmpeg', '-y', '-v', 'error', *inputs, '-filter_complex', ';'.join(parts),
         '-map', '[v]', '-t', f'{dur}', '-r', str(FPS), *enc, '-an', out])
    return out


def build_seq_scene(scene, fmt, dur, draft):
    out = f"{TMP}/{fmt}/{scene['id']}.mp4"
    enc = ['-c:v', 'libx264', '-preset', 'veryfast' if draft else 'slow', '-crf', '24' if draft else '16']
    os.makedirs(os.path.dirname(out), exist_ok=True)
    run(['ffmpeg', '-y', '-v', 'error', '-i', f"{GFX}/{fmt}/{scene['seq']}.mp4",
         '-vf', f'fps={FPS},tpad=stop_mode=clone:stop_duration={dur},trim=0:{dur},format=yuv420p',
         '-r', str(FPS), *enc, '-an', out])
    return out


def timeline():
    t, rows = 0.0, []
    for i, s in enumerate(SCENES):
        d = scene_len(s)
        rows.append((s, t, d))
        t += d - XF
    return rows, t + XF


# Music is 3:00 at ~89 BPM; 32 beats from 1:40 are played twice to reach the
# video's length, so its own ending still lands under the signature.
LOOP_FROM, LOOP_TO = 100.287, 122.114  # beat times, 32 beats apart
MUSIC_IN = 4.853  # skip the first few quiet beats so the ending lines up


def fit_music(out):
    src = f'{ROOT}/work/audio/music.wav'
    if not os.path.exists(src):
        run(['ffmpeg', '-y', '-v', 'error', '-i', f'{AUD}/music.mp4', '-ar', '48000', src])
    run(['ffmpeg', '-y', '-v', 'error', '-i', src, '-i', src, '-filter_complex',
         f'[0:a]atrim={MUSIC_IN}:{LOOP_TO},asetpts=PTS-STARTPTS[a];'
         f'[1:a]atrim={LOOP_FROM}:180.02,asetpts=PTS-STARTPTS[b];'
         '[a][b]acrossfade=d=0.03:c1=tri:c2=tri[m]', '-map', '[m]', out])


def build_audio(rows, total, out):
    inputs, parts, labels = [], [], []
    idx = 0

    def add(path, at, gain_db=0.0, label=None):
        nonlocal idx
        inputs.extend(['-i', path])
        ms = int(at * 1000)
        name = label or f'a{idx}'
        parts.append(f'[{idx}:a]aformat=sample_rates=48000:channel_layouts=stereo,'
                     f'volume={gain_db}dB,adelay={ms}|{ms}[{name}]')
        labels.append(name)
        idx += 1

    vo_labels, sfx_labels = [], []
    for s, start, d in rows:
        p = f"{AUD}/{s['vo']}.mp3"
        if os.path.exists(p):
            add(p, start + s['vo_at'], 0.0)
            vo_labels.append(labels[-1])
        for sid, at, g in s.get('sfx', []):
            add(f'{AUD}/{sid}.wav', start + at, g)
            sfx_labels.append(labels[-1])
    music = f'{ROOT}/work/audio/music_fit.wav'
    fit_music(music)
    inputs.extend(['-i', music])
    mi = idx
    parts.append(f'[{mi}:a]aformat=sample_rates=48000:channel_layouts=stereo,volume=-7dB,'
                 f'afade=t=out:st={total - 2.5}:d=2.5[mus]')
    parts.append(''.join(f'[{l}]' for l in vo_labels) + f'amix=inputs={len(vo_labels)}:normalize=0,asplit=2[vo][vk]')
    parts.append('[vk]apad[vokey]')  # keep the sidechain alive to the end
    parts.append('[mus][vokey]sidechaincompress=threshold=0.02:ratio=8:attack=30:release=600:makeup=1[duck]')
    parts.append(''.join(f'[{l}]' for l in sfx_labels) + f'amix=inputs={len(sfx_labels)}:normalize=0[sfx]')
    parts.append('[vo][duck][sfx]amix=inputs=3:normalize=0,alimiter=limit=0.89,'
                 f'loudnorm=I=-16:TP=-1.5:LRA=11,atrim=0:{total}[out]')
    run(['ffmpeg', '-y', '-v', 'error', *inputs, '-filter_complex', ';'.join(parts),
         '-map', '[out]', '-ar', '48000', '-c:a', 'pcm_s16le', out])


def join(files, rows, out_video):
    inputs = []
    for f in files:
        inputs += ['-i', f]
    parts, cur, off = [], '0:v', 0.0
    for i in range(1, len(files)):
        off += rows[i - 1][2] - XF
        parts.append(f'[{cur}][{i}:v]xfade=transition=fade:duration={XF}:offset={off:.3f}[x{i}]')
        cur = f'x{i}'
    run(['ffmpeg', '-y', '-v', 'error', *inputs, '-filter_complex', ';'.join(parts),
         '-map', f'[{cur}]', '-c:v', 'libx264', '-preset', 'slow', '-crf', '17',
         '-pix_fmt', 'yuv420p', '-r', str(FPS), out_video])


def main():
    args = sys.argv[1:]
    which = [a for a in args if a in ('wide', 'tall', 'both')] or ['both']
    fmts = ['wide', 'tall'] if which[0] == 'both' else which
    draft = '--draft' in args
    only = None
    if '--scenes' in args:
        only = set(args[args.index('--scenes') + 1].split(','))
    rows, total = timeline()
    os.makedirs(OUT, exist_ok=True)
    with open(f'{ROOT}/work/timeline.json', 'w') as f:
        json.dump([{'id': s['id'], 'start': round(t, 3), 'dur': round(d, 3)} for s, t, d in rows]
                  + [{'total': round(total, 3)}], f, indent=1)
    print(f'total {total:.2f}s')
    for fmt in fmts:
        files = []
        for s, t, d in rows:
            out = f"{TMP}/{fmt}/{s['id']}.mp4"
            if only is None or s['id'] in only:
                print('scene', fmt, s['id'], f'{d:.2f}s', flush=True)
                out = build_seq_scene(s, fmt, d, draft) if 'seq' in s else build_app_scene(s, fmt, d, draft)
            files.append(out)
        if only is not None:
            continue
        video = f'{ROOT}/work/{fmt}_video.mp4'
        join(files, rows, video)
        audio = f'{ROOT}/work/mix.wav'
        if not os.path.exists(audio) or fmt == fmts[0]:
            build_audio(rows, total, audio)
        final = f"{OUT}/redkeep-promo-{'16x9' if fmt == 'wide' else '9x16'}.mp4"
        run(['ffmpeg', '-y', '-v', 'error', '-i', video, '-i', audio, '-map', '0:v', '-map', '1:a',
             '-c:v', 'copy', '-c:a', 'aac', '-b:a', '256k', '-movflags', '+faststart',
             '-shortest', final])
        print('wrote', final)


if __name__ == '__main__':
    main()
