import numpy as np, sys, os, wave
SR=44100
raw, out = sys.argv[1], sys.argv[2]
os.makedirs(out, exist_ok=True)
def load(n): return np.fromfile(f"{raw}/{n}.f32", dtype=np.float32).astype(np.float64)
def env(x, w=88): return np.convolve(np.abs(x), np.ones(w)/w, 'same')

def one_shot(x, onset_hint=None, max_ms=250, pre_ms=1.5, fade_ms=15):
    e = env(x)
    pk = e.max() if onset_hint is None else e[onset_hint:onset_hint+int(SR*0.03)].max()
    if onset_hint is None:
        start = int(np.argmax(e > pk*0.3))
    else:
        seg = e[max(onset_hint-int(SR*0.03),0):onset_hint+int(SR*0.03)]
        start = max(onset_hint-int(SR*0.03),0) + int(np.argmax(seg > pk*0.3))
    start = max(start - int(SR*pre_ms/1000), 0)
    # posun na první výraznou špičku (úder), ne na tichý předšum
    w = np.abs(x[start:start+int(SR*0.004)])
    if len(w): start = max(start + int(np.argmax(w > w.max()*0.25)) - int(SR*0.0008), 0)
    y = x[start:start+int(SR*max_ms/1000)]
    ey = env(y, 441)
    peak_i = int(np.argmax(ey))
    below = np.flatnonzero(ey[peak_i:] < ey.max()*0.02)
    end = peak_i + (int(below[0]) if len(below) else len(y)-peak_i)
    end = min(max(end + int(SR*0.01), int(SR*0.04)), len(y))
    y = y[:end].copy()
    fi = int(SR*0.0005); y[:fi] *= np.linspace(0,1,fi)
    fo = min(int(SR*fade_ms/1000), len(y)//3); y[-fo:] *= np.linspace(1,0,fo)**2
    y -= np.mean(y[:min(len(y),64)])*0  # no DC shift
    return y

def loudness(y):  # RMS prvních 40 ms (úder)
    n=min(len(y), int(SR*0.04)); return np.sqrt(np.mean(y[:n]**2))

def norm(y, target=0.12, cap=0.89):
    g = target/ max(loudness(y),1e-9)
    g = min(g, cap/np.abs(y).max())
    return y*g

def pitch(y, f):  # jednoduché převzorkování
    n = int(len(y)/f); src = np.arange(n)*f
    return np.interp(src, np.arange(len(y)), y)

def write(name, y):
    y = np.clip(y, -1, 1)
    with wave.open(f"{out}/{name}.wav", "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((y*32767).astype('<i2').tobytes())
    print(f"{name}: {len(y)/SR*1000:.0f} ms, peak {np.abs(y).max():.2f}")

def variants(pack, base, factors, target):
    for i,f in enumerate(factors,1):
        write(f"key-{pack}-{i}", norm(pitch(base,f), target))

# Soft – Mixkit „Typewriter soft click“
variants("soft", one_shot(load("mixkit-typewriter-soft-click"), max_ms=120), [0.96,1.0,1.04,1.08], 0.07)
# Clicky – Mixkit „Hard typewriter click“
variants("clicky", one_shot(load("mixkit-hard-typewriter-click"), max_ms=110), [0.97,1.0,1.03,1.06], 0.13)
# Typewriter – Freesound 9098 (ddohler) + Mixkit „Mechanical typewriter single hit“
tw = one_shot(load("freesound-9098-ddohler-typewriter"), max_ms=260)
mkr = load("mixkit-mechanical-typewriter-single-hit")
# hlavní úder je až po ~50 ms hluku mechanismu → začneme přímo u úderu
mkp = int(np.argmax(np.abs(mkr)))
mk = one_shot(mkr[max(mkp-int(SR*0.002),0):], max_ms=200)
for i,(b,f) in enumerate([(tw,0.97),(tw,1.0),(tw,1.04),(mk,1.0),(mk,1.04)],1):
    write(f"key-typewriter-{i}", norm(pitch(b,f), 0.14))

# Mechanical – Freesound 860426: izolované úhozy z rychlého psaní
x = load("freesound-860426-mechanical-keyboard"); e = env(x, 220)
thr = e.max()*0.25; above = e>thr
on=[]; last=-10**9
for i in np.flatnonzero(above[1:]&~above[:-1]):
    if i-last>SR*0.06: on.append(i); last=i
cands=[]
for k,o in enumerate(on):
    prev = on[k-1] if k else -10**9; nxt = on[k+1] if k+1<len(on) else 10**9
    if o-prev < SR*0.12 or nxt-o < SR*0.16: continue
    shot = one_shot(x, onset_hint=o, max_ms=85, fade_ms=30)
    pre = x[max(o-int(SR*0.05),0):o-int(SR*0.01)]
    noise = np.sqrt(np.mean(pre**2)) if len(pre) else 1
    cands.append((loudness(shot), noise, o, shot))
lv = np.array([c[0] for c in cands]); med = np.median(lv)
# podobná hlasitost (stisky, ne uvolnění), čistý začátek
good = [c for c in cands if med*0.9 < c[0] < med*1.8 and c[1] < c[0]*0.25]
good.sort(key=lambda c: c[2])
pick = [good[int(i)] for i in np.linspace(0, len(good)-1, 8)] if len(good)>=8 else good
print(f"mechanical: {len(on)} úhozů, {len(cands)} izolovaných, {len(good)} vhodných")
for i,c in enumerate(pick,1):
    write(f"key-mechanical-{i}", norm(c[3], 0.12))
