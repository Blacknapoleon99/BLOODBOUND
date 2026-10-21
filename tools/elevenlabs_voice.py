"""Voice lines for BLOODBOUND with ElevenLabs: every line of a speaker uses the same library voice,
so a character always sounds like itself. (Designing/saving custom voices needs a paid plan, so
the free account uses ElevenLabs default voices: Adam for the Bishop, Harry for the knight; premium library voices are paid-only too.)
The Bishop's demonic-robot character is baked in here by `demonize` (pitch down, ring
modulation, distortion grit, cathedral echo), identical for every line.

Usage (costs credits: TTS ~1 credit per character, voice design per preview; ask first):
    python tools/elevenlabs_voice.py --key-file PATH            # everything not cached
    python tools/elevenlabs_voice.py --key-file PATH vo_slam    # only these line ids

Raw TTS is cached in tools/.elevenlabs_cache/vo_<id>.pcm (rerunning only re-processes). Lines go to assets/audio/<id>.wav (22050 Hz mono, trimmed, peak-normalised). The key is never printed.
"""
import array
import base64
import json
import math
import os
import sys
import urllib.error
import urllib.request
import wave

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "audio")
CACHE = os.path.join(ROOT, "tools", ".elevenlabs_cache")
VOICES_FILE = os.path.join(CACHE, "voices.json")
RATE = 22050
TTS_MODEL = "eleven_v4"
API_KEY = ""

VOICE_IDS = {
    "bishop": "pNInz6obpgDQGcFmaJgB",  # Adam - Dominant, Firm (default voice), demonized below
    "knight": "SOYHLrjzK2X1ezoPC6cr",  # Harry - Fierce Warrior (young, rough)
}
# What each speaker should sound like (used if a paid plan ever designs custom voices).
SPEAKERS = {
    "bishop": "An ancient colossal demon-machine priest. Extremely deep, slow and menacing male voice, "
              "metallic and robotic with a grinding mechanical buzz, distorted like a corrupted cathedral "
              "organ speaking, cruel, gory, sermon-like delivery.",
    "knight": "A young battle-hardened male knight in his late twenties, gritty and breathy, strong "
              "physical voice suited to pained grunts, battle cries and screams, slight British accent.",
}

# id: (speaker, text, peak)
LINES = {
    "vo_awaken": ("bishop", "Kneel, little lamb... The Covenant hungers.", 0.95),
    "vo_fight": ("bishop", "You walk into my cathedral. You will never walk out of it.", 0.95),
    "vo_phase2": ("bishop", "Let the bridge of the faithful crumble beneath you!", 0.95),
    "vo_phase3": ("bishop", "Blood for the Covenant! Flesh for the choir!", 0.95),
    "vo_phase4": ("bishop", "I am unmade... but I will drag you into the dark with me!", 0.95),
    "vo_slam": ("bishop", "Be crushed!", 0.95),
    "vo_beam": ("bishop", "Burn in the light of the dead!", 0.95),
    "vo_summon": ("bishop", "Rise, my children. Feast.", 0.95),
    "vo_rain": ("bishop", "The heavens bleed bone!", 0.95),
    "vo_geyser": ("bishop", "Even the earth rejects you!", 0.95),
    "vo_taunt": ("bishop", "Another soul for the reliquary.", 0.95),
    "vo_death": ("bishop", "The Covenant... is... broken...", 0.95),
    "player_hurt": ("knight", "Ugh!", 0.85),
    "player_hurt_2": ("knight", "Agh!", 0.85),
    "player_hurt_3": ("knight", "Ouch!", 0.85),
    "player_hurt_4": ("knight", "Hngh!", 0.85),
    "player_fall": ("knight", "Aaaaaaaaaahhhhhhhhhh!", 0.9),
    "player_death": ("knight", "No... not... like this...", 0.85),
    "player_effort": ("knight", "Haaah!", 0.8),
    "player_effort_2": ("knight", "Hyah!", 0.8),
}


def _request(url: str, body: dict | None = None) -> bytes:
    data = json.dumps(body).encode() if body is not None else None
    request = urllib.request.Request(url, data=data, method="POST" if body is not None else "GET",
                                     headers={"xi-api-key": API_KEY, "Content-Type": "application/json"})
    with urllib.request.urlopen(request, timeout=180) as response:
        return response.read()


def load_key(args: list) -> list:
    global API_KEY
    rest = list(args)
    path = os.environ.get("ELEVENLABS_KEY_FILE", "")
    if "--key-file" in rest:
        i = rest.index("--key-file")
        path = rest[i + 1]
        del rest[i:i + 2]
    if path:
        with open(path, encoding="utf-8-sig") as f:
            API_KEY = f.read().strip()
    else:
        API_KEY = os.environ.get("ELEVENLABS_API_KEY", "")
    return rest


def demonize(samples: list) -> list:
    """Same robotic-demon treatment for every Bishop line (floats in -1..1)."""
    # 1. Pitch (and tempo) down by resampling: slower, deeper, heavier.
    factor = 0.8
    n = int(len(samples) / factor)
    low = []
    for i in range(n):
        x = i * factor
        j = int(x)
        frac = x - j
        a = samples[j] if j < len(samples) else 0.0
        b = samples[j + 1] if j + 1 < len(samples) else 0.0
        low.append(a + (b - a) * frac)
    out = []
    for i, v in enumerate(low):
        t = i / RATE
        ring = v * math.sin(2.0 * math.pi * 60.0 * t)           # metallic robot ring-mod
        grit = math.tanh(v * 4.0) * 0.5                          # gory distortion
        crushed = round(v * 24.0) / 24.0                         # machine bit-grit
        out.append(0.45 * v + 0.35 * ring + 0.25 * grit + 0.15 * crushed)
    # 2. Cathedral echo.
    delay = int(RATE * 0.13)
    for i in range(delay, len(out)):
        out[i] += out[i - delay] * 0.32
    tail = [0.0] * int(RATE * 0.5)
    for i in range(len(tail)):
        k = len(out) - delay + i
        tail[i] = out[k] * 0.32 if 0 <= k < len(out) else 0.0
    return out + tail


def voice_id(speaker: str, voices: dict) -> str:
    if speaker in VOICE_IDS:
        return VOICE_IDS[speaker]
    if speaker in voices:
        return voices[speaker]
    design = json.loads(_request("https://api.elevenlabs.io/v1/text-to-voice/design?output_format=mp3_22050_32", {
        "voice_description": SPEAKERS[speaker], "model_id": "eleven_ttv_v3", "auto_generate_text": True,
        "guidance_scale": 6, "seed": 1666}))
    preview = design["previews"][0]
    created = json.loads(_request("https://api.elevenlabs.io/v1/text-to-voice", {
        "voice_name": "Bloodbound - " + speaker, "voice_description": SPEAKERS[speaker],
        "generated_voice_id": preview["generated_voice_id"]}))
    voices[speaker] = created["voice_id"]
    with open(VOICES_FILE, "w", encoding="utf-8") as f:
        json.dump(voices, f, indent=2)
    with open(os.path.join(CACHE, "voice_preview_%s.mp3" % speaker), "wb") as f:
        f.write(base64.b64decode(preview["audio_base_64"]))
    print("designed voice for %s" % speaker)
    return voices[speaker]


def _corr(x, y) -> float:
    n = min(len(x), len(y))
    if n < 2:
        return 0.0
    mx = sum(x[:n]) / n
    my = sum(y[:n]) / n
    num = sum((x[i] - mx) * (y[i] - my) for i in range(n))
    den = math.sqrt(sum((x[i] - mx) ** 2 for i in range(n)) * sum((y[i] - my) ** 2 for i in range(n))) or 1.0
    return num / den


def to_mono(samples: array.array) -> array.array:
    """The API's pcm output has been seen as interleaved stereo: detect it and downmix."""
    probe = samples[: min(len(samples), 40000) // 2 * 2]
    even, odd = probe[0::2], probe[1::2]
    if _corr(even, odd) < 0.5 and _corr(even[:-1], even[1:]) > 0.6:
        return array.array("h", ((samples[i] + samples[i + 1]) // 2 for i in range(0, len(samples) - 1, 2)))
    return samples


def write_wav(line_id: str, pcm: bytes, peak: float, speaker: str = "") -> None:
    samples = array.array("h")
    samples.frombytes(pcm)
    if sys.byteorder == "big":
        samples.byteswap()
    samples = to_mono(samples)
    if speaker == "bishop":
        top0 = max(1, max(abs(s) for s in samples))
        processed = demonize([s / top0 for s in samples])
        samples = array.array("h", (max(-32767, min(32767, int(v * 20000))) for v in processed))
    top = max(1, max(abs(s) for s in samples))
    start = next((i for i, s in enumerate(samples) if abs(s) > top * 0.03), 0)
    end = len(samples) - next((i for i, s in enumerate(reversed(samples)) if abs(s) > top * 0.015), 0)
    samples = samples[max(0, start - int(RATE * 0.005)):end]
    fade = min(len(samples), int(RATE * 0.03))
    for i in range(fade):
        samples[len(samples) - fade + i] = int(samples[len(samples) - fade + i] * (1.0 - i / fade))
    gain = peak * 32767 / top
    samples = array.array("h", (max(-32767, min(32767, int(s * gain))) for s in samples))
    with wave.open(os.path.join(OUT, line_id + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(samples.tobytes())


def main() -> int:
    args = load_key(sys.argv[1:])
    if not API_KEY:
        print("No API key: pass --key-file PATH or set ELEVENLABS_API_KEY")
        return 1
    os.makedirs(CACHE, exist_ok=True)
    voices = json.load(open(VOICES_FILE, encoding="utf-8")) if os.path.exists(VOICES_FILE) else {}
    ids = args or list(LINES)
    failed = 0
    for line_id in ids:
        speaker, text, peak = LINES[line_id]
        cache_file = os.path.join(CACHE, "vo_" + line_id + ".pcm")
        try:
            if not os.path.exists(cache_file):
                vid = voice_id(speaker, voices)
                settings = {"stability": 0.35, "similarity_boost": 0.85, "style": 0.6} if speaker == "bishop" else {"stability": 0.3, "similarity_boost": 0.8, "style": 0.8}
                pcm = _request("https://api.elevenlabs.io/v1/text-to-speech/%s?output_format=pcm_22050" % vid,
                               {"text": text, "model_id": TTS_MODEL, "voice_settings": settings})
                with open(cache_file, "wb") as f:
                    f.write(pcm)
                status = "generated"
            else:
                status = "cached"
            write_wav(line_id, open(cache_file, "rb").read(), peak, speaker)
            print("%-16s %s" % (line_id, status))
        except urllib.error.HTTPError as error:
            failed += 1
            print("%-16s HTTP %d: %s" % (line_id, error.code, error.read()[:300].decode(errors="replace")))
    print("done: %d ok, %d failed" % (len(ids) - failed, failed))
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
