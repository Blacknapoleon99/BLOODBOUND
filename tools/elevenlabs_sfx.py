"""Generate BLOODBOUND's sound effects and music loops with the ElevenLabs Sound Effects API.

Usage (costs ElevenLabs credits, billed per second of audio, so get approval before running):
    python tools/elevenlabs_sfx.py            # generate everything not already cached
    python tools/elevenlabs_sfx.py slash land # only these ids

The API key is read from the ELEVENLABS_API_KEY environment variable and never printed.
Raw responses are cached in tools/.elevenlabs_cache/ (git-ignored), so rerunning only pays for
missing sounds; delete a cached .pcm to regenerate that sound. Output (the API's 16-bit stereo PCM, downmixed) is written to
assets/audio/<id>.wav (22050 Hz, 16-bit mono): leading/trailing silence trimmed for snappy
hits, peak-normalised. Music is generated as seamless loops and left untrimmed.
Note: tools/generate_audio.gd (the synthesized fallback) overwrites the same files if rerun.
"""
import array
import json
import os
import sys
import urllib.error
import urllib.request
import wave
from concurrent.futures import ThreadPoolExecutor

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "audio")
CACHE = os.path.join(ROOT, "tools", ".elevenlabs_cache")
RATE = 22050
URL = "https://api.elevenlabs.io/v1/sound-generation?output_format=pcm_22050"
STYLE = "dark gothic fantasy video game sound effect, "

# id: (prompt, duration seconds, loop, peak)
SOUNDS = {
    "slash": ("quick short sword swipe whoosh, a light blade cutting air", 0.5, False, 0.8),
    "slash_finisher": ("heavy final sword slash with a sharp metallic ring and whoosh", 0.7, False, 0.85),
    "heavy_swing": ("massive greatsword swing, deep heavy whoosh with effort", 0.8, False, 0.85),
    "hit_flesh": ("blade striking rotten flesh and bone, wet meaty impact", 0.5, False, 0.85),
    "hit_weak": ("critical hit on a glowing weak point, crunchy impact with a bright magical crack", 0.8, False, 0.9),
    "player_hurt": ("male warrior grunts in pain as he is struck, short", 0.6, False, 0.8),
    "dodge": ("fast cloth rustle dash whoosh, quick evasive roll", 0.5, False, 0.7),
    "jump": ("light leather boots jump off stone, short", 0.5, False, 0.5),
    "land": ("boots landing on stone floor, short soft thud", 0.5, False, 0.5),
    "death": ("hero dies, final gasp and body collapsing on stone with armor clatter", 1.6, False, 0.85),
    "card_spear": ("spear of liquid blood hurled, wet whoosh with a magical hiss", 0.8, False, 0.85),
    "card_shield": ("iron ward of grave metal raised, magical shimmering clang", 1.0, False, 0.8),
    "card_chains": ("spectral chains lashing out and binding, rattling metal with magic", 1.0, False, 0.85),
    "card_bell": ("single deep cathedral bell toll that silences, long eerie resonance", 2.2, False, 0.85),
    "card_epitaph": ("bone spike erupting violently from stone ground, crack and stab", 0.8, False, 0.9),
    "card_pact": ("blood pact, dagger cuts flesh followed by a dark magical heartbeat whoosh", 1.0, False, 0.8),
    "card_choir": ("ghostly choir phantom summoned, ethereal haunting voices swelling", 1.6, False, 0.8),
    "card_transfusion": ("healing blood magic, warm swelling shimmer with a heartbeat", 1.2, False, 0.75),
    "card_refused": ("short dull error thunk, a spell fizzling out", 0.5, False, 0.6),
    "bishop_roar": ("colossal undead skeletal giant roaring, deep monstrous bellow echoing in a cathedral", 2.4, False, 0.95),
    "bishop_slam": ("gigantic bone hand slamming into a stone causeway, huge crushing impact with rubble", 1.4, False, 0.95),
    "lance_whistle": ("giant bone lance hurled from afar, rising whistling whoosh", 1.2, False, 0.8),
    "censer_swing": ("huge iron censer on chains swinging, heavy whoosh with rattling chains and embers", 1.6, False, 0.85),
    "beam_charge": ("dark magical energy charging up, rising ominous hum building to a peak", 1.3, False, 0.8),
    "beam_fire": ("searing red death beam firing, roaring blast of unholy energy", 1.6, False, 0.9),
    "summon": ("undead rising from the ground, gravel and bones cracking with ghostly moans", 1.5, False, 0.85),
    "archer_draw": ("bow string being drawn taut, wooden creak", 0.8, False, 0.7),
    "arrow_release": ("arrow released from a bow, twang and quick whoosh", 0.5, False, 0.8),
    "walls_rise": ("walls of bone erupting from the ground, grinding cracking rumble", 1.0, False, 0.85),
    "altar": ("blood altar activated, low mystical hum and a dripping chime", 1.6, False, 0.75),
    "ui_click": ("subtle soft UI click, dark menu button", 0.5, False, 0.45),
    "victory": ("triumphant but somber gothic choir and organ chord, victory sting", 3.0, False, 0.85),
    "bone_rain": ("bones raining down from above and shattering on stone, many cracking impacts", 1.4, False, 0.85),
    "geyser": ("bone marrow spike bursting up from the ground with a wet crack", 0.9, False, 0.9),
    "hound_pounce": ("skeletal hound snarling and leaping to attack", 0.7, False, 0.85),
    "husk_burst": ("rotting corpse bursting into a cloud of plague gas, wet pop and hiss", 0.9, False, 0.85),
    "soldier_lunge": ("undead soldier growls and lunges forward with a blade, aggressive", 0.8, False, 0.85),
    "equip": ("equipping armor and weapon, leather and metal buckle clink", 0.6, False, 0.7),
    "music_level": ("dark ambient gothic music loop, low droning choir and distant cathedral bells, ominous and slow, no percussion", 24.0, True, 0.7),
    "music_boss": ("intense dark gothic boss battle music loop, pounding war drums, pipe organ and choir, 120 bpm", 16.0, True, 0.8),
}


def generate(sound_id: str) -> str:
    prompt, duration, loop, _peak = SOUNDS[sound_id]
    cache_file = os.path.join(CACHE, sound_id + ".pcm")
    if os.path.exists(cache_file):
        return "cached"
    text = prompt if sound_id.startswith("music") else STYLE + prompt
    body = {"text": text, "duration_seconds": duration, "prompt_influence": 0.5, "loop": loop, "model_id": "eleven_text_to_sound_v2"}
    request = urllib.request.Request(URL, data=json.dumps(body).encode(), method="POST", headers={
        "xi-api-key": os.environ["ELEVENLABS_API_KEY"], "Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(request, timeout=180) as response:
            data = response.read()
    except urllib.error.HTTPError as error:
        return "HTTP %d: %s" % (error.code, error.read()[:300].decode(errors="replace"))
    with open(cache_file, "wb") as f:
        f.write(data)
    return "generated %.1fs" % (len(data) / 4 / RATE)  # 16-bit stereo


def write_wav(sound_id: str) -> None:
    _prompt, _duration, loop, peak = SOUNDS[sound_id]
    samples = array.array("h")
    with open(os.path.join(CACHE, sound_id + ".pcm"), "rb") as f:
        samples.frombytes(f.read())
    if sys.byteorder == "big":
        samples.byteswap()
    # The API returns interleaved stereo for pcm_22050: downmix to mono.
    samples = array.array("h", ((samples[i] + samples[i + 1]) // 2 for i in range(0, len(samples) - 1, 2)))
    top = max(1, max(abs(s) for s in samples))
    if not loop:
        # Trim quiet lead-in (instant response) and tail, then fade the last 25 ms.
        start = next((i for i, s in enumerate(samples) if abs(s) > top * 0.04), 0)
        end = len(samples) - next((i for i, s in enumerate(reversed(samples)) if abs(s) > top * 0.02), 0)
        samples = samples[max(0, start - int(RATE * 0.003)):end]
        fade = min(len(samples), int(RATE * 0.025))
        for i in range(fade):
            samples[len(samples) - fade + i] = int(samples[len(samples) - fade + i] * (1.0 - i / fade))
    gain = peak * 32767 / top
    samples = array.array("h", (max(-32767, min(32767, int(s * gain))) for s in samples))
    with wave.open(os.path.join(OUT, sound_id + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(samples.tobytes())


def main() -> int:
    if not os.environ.get("ELEVENLABS_API_KEY"):
        print("ELEVENLABS_API_KEY is not set")
        return 1
    os.makedirs(CACHE, exist_ok=True)
    ids = sys.argv[1:] or list(SOUNDS)
    with ThreadPoolExecutor(max_workers=4) as pool:
        results = dict(zip(ids, pool.map(generate, ids)))
    failed = 0
    for sound_id in ids:
        status = results[sound_id]
        print("%-18s %s" % (sound_id, status))
        if status.startswith("HTTP"):
            failed += 1
            continue
        write_wav(sound_id)
    print("done: %d ok, %d failed" % (len(ids) - failed, failed))
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
