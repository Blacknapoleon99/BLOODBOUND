"""Generate BLOODBOUND's sound effects and music loops with the ElevenLabs Sound Effects API.

Usage (costs ElevenLabs credits, billed per second of audio, so get approval before running):
    python tools/elevenlabs_sfx.py                       # generate everything not already cached
    python tools/elevenlabs_sfx.py slash land            # only these ids
    python tools/elevenlabs_sfx.py --key-file PATH ...   # read the key from a text file
    python tools/elevenlabs_sfx.py --credits [--key-file PATH]  # show remaining credits only

The API key comes from --key-file (a file containing only the key), else ELEVENLABS_KEY_FILE,
else the ELEVENLABS_API_KEY environment variable. It is never printed or written anywhere.
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
STYLE = "dark gothic fantasy video game sound effect, high quality, "

# id: (prompt, duration seconds, loop, peak)
SOUNDS = {
    "slash": ("single fast slash of a notched iron longsword, sharp steel whoosh with a faint metallic shing, dry, close-mic, no impact", 0.5, False, 0.8),
    "slash_finisher": ("powerful spinning longsword finisher, heavy double whoosh ending in a ringing steel shing and a grunt of effort", 0.8, False, 0.85),
    "heavy_swing": ("enormous two-handed greatsword swung overhead, deep slow air-tearing whoosh, armour creak, heavy breath", 0.9, False, 0.85),
    "hit_flesh": ("sword blade hacking into rotten undead flesh: wet squelch, crunch of brittle bone, short and punchy", 0.5, False, 0.85),
    "hit_weak": ("blade stabbing a glowing demonic heart weak point: deep meaty thud, glassy crystalline crack, burst of hissing blood magic", 0.9, False, 0.9),
    "player_hurt": ("armoured knight hit hard: sharp pained grunt, chainmail jingle and a dull thump on the breastplate", 0.6, False, 0.8),
    "dodge": ("swift evasive roll in a heavy cloak: fabric snap, quick whoosh and boots skidding on stone", 0.5, False, 0.7),
    "jump": ("knight leaps off a stone floor: short boot scuff and leather creak with a soft exhale", 0.5, False, 0.5),
    "land": ("armoured knight lands on stone after a jump: boots thud, chainmail rattle, tiny gravel scatter", 0.5, False, 0.5),
    "death": ("knight is slain: choking final gasp, sword clattering on flagstones, body and armour collapsing, fading heartbeat", 2.0, False, 0.85),
    "card_spear": ("a spear of liquid blood forms and is hurled: wet sloshing condense, then a fast piercing whoosh with a dark magical hiss", 0.9, False, 0.85),
    "card_shield": ("an iron tombstone ward slams up in front of the hero: heavy grave-metal clang, echoing shimmer of protective magic", 1.0, False, 0.8),
    "card_chains": ("ghostly iron chains erupt from the ground and lash around a giant hand: rattling links, whip crack, cold spectral whisper", 1.2, False, 0.85),
    "card_bell": ("one enormous cracked cathedral bell tolls once, a deep bronze BONG with a long eerie decaying shimmer that swallows all other sound", 2.5, False, 0.85),
    "card_epitaph": ("a jagged bone spike tears up out of a stone floor: grinding rumble, violent crack and splinter, wet stab", 0.9, False, 0.9),
    "card_pact": ("a blood pact: a ritual dagger slicing a palm, sharp hiss of pain, then a deep ominous heartbeat and dark whispering surge", 1.2, False, 0.8),
    "card_choir": ("a ghostly phantom choir materialises: breathy eerie female voices swelling in a minor chord, cold wind, spectral shimmer", 1.6, False, 0.8),
    "card_transfusion": ("blood healing magic: thick liquid flowing upward, warm resonant hum and a slowing comforting heartbeat", 1.2, False, 0.75),
    "card_refused": ("failed spell: dry hollow wooden thunk with a short fizzle and puff of dying embers", 0.5, False, 0.6),
    "bishop_roar": ("a colossal skeletal undead bishop roars: guttural demonic bellow layered with a distorted choir scream and grinding bones, huge cathedral reverb", 3.0, False, 0.95),
    "bishop_slam": ("a giant skeletal hand the size of a house smashes down through a stone bridge: thunderous boom, shattering masonry, bone crunch, debris rain", 1.6, False, 0.95),
    "lance_whistle": ("a huge bone javelin hurled from far away: rising shrill whistle tearing through the air, ending in a heavy stone impact", 1.3, False, 0.8),
    "censer_swing": ("a giant brass church censer on thick chains swings past: deep heavy whoosh, chain rattle, crackling embers and incense hiss", 1.6, False, 0.85),
    "beam_charge": ("an unholy red energy beam charging inside a giant ribcage: rising dissonant hum, crackling electricity, ominous choir building", 1.4, False, 0.8),
    "beam_fire": ("a searing blood-red death ray fires and sweeps: sustained roaring blast, sizzling burning stone, distorted low hum", 1.8, False, 0.9),
    "summon": ("corpses claw their way out of a graveyard: cracking earth, snapping bones, rasping undead moans rising", 1.6, False, 0.85),
    "archer_draw": ("skeleton archer slowly draws a bone bow: creaking wood and taut sinew string, bones clicking", 0.9, False, 0.7),
    "arrow_release": ("arrow released from a war bow: sharp string thwack and quick arrow whizz past", 0.5, False, 0.8),
    "walls_rise": ("walls of fused bone erupt from the floor to trap you: deep grinding rumble, cracking bones, a menacing slam at the end", 1.3, False, 0.85),
    "altar": ("a blood altar awakens: low sacred drone, dripping blood, a soft ritual chime and distant whispered prayer", 1.8, False, 0.75),
    "ui_click": ("dark fantasy menu click: soft muted stone tap with a tiny metallic tick", 0.5, False, 0.45),
    "victory": ("dark souls style victory: a huge boss falls, deep rumble fades into a solemn swelling choir and pipe organ chord", 4.0, False, 0.85),
    "bone_rain": ("dozens of bones fall from a high cathedral ceiling and shatter on stone, rapid cracking clatter like hail", 1.5, False, 0.85),
    "geyser": ("a spike of bone marrow bursts violently from the ground: wet gushing pop, crunching bone, splatter", 0.9, False, 0.9),
    "hound_pounce": ("a skeletal hellhound snarls and leaps: vicious growl, clacking jaws, bones rattling in the air", 0.8, False, 0.85),
    "husk_burst": ("a bloated plague zombie bursts: sickening wet pop, gassy hiss of rot, splattering gore", 1.0, False, 0.85),
    "soldier_lunge": ("undead plague soldier lunges: raspy war cry, armour clank, fast blade thrust whoosh", 0.8, False, 0.85),
    "equip": ("equipping heavy gear: leather strap tightening, metal buckle click, armour plate settling", 0.7, False, 0.7),
    "card_step": ("shadow teleport: a short dark whoosh sucked into a void, then a soft pop of displaced air", 0.6, False, 0.8),
    "card_hook": ("a bone grappling hook flung on a chain: rattling throw, meaty hook impact, fast pull whoosh", 0.8, False, 0.85),
    "card_bridge": ("a bridge of bone grows rapidly: crackling, knitting, grinding bones forming a solid slab", 1.0, False, 0.8),
    "card_nova": ("a ring of blood explodes outward from the hero: deep concussive boom, wet splash, rushing shockwave", 1.0, False, 0.9),
    "card_haste": ("a haste spell: rising shimmering whoosh, a quickening heartbeat and a bright magical sparkle", 0.9, False, 0.8),
    "loot_drop": ("a sacred golden reliquary rises from stone after a boss dies: rumbling grind, glittering chime and a soft angelic choir note", 1.8, False, 0.8),
    "music_level": ("dark ambient gothic exploration music loop, low tense drones, distant tolling cathedral bell, sparse eerie choir pads, slow cello, ominous and atmospheric, no percussion", 30.0, True, 0.7),
    "music_boss": ("epic dark gothic boss battle music loop, thunderous taiko and war drums, aggressive staccato strings, pipe organ and latin choir chanting, 130 bpm, relentless", 30.0, True, 0.8),
}


API_KEY = ""


def load_key(args: list) -> list:
    """Sets API_KEY from --key-file / ELEVENLABS_KEY_FILE / ELEVENLABS_API_KEY; returns the other args."""
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


def credits() -> str:
    request = urllib.request.Request("https://api.elevenlabs.io/v1/user/subscription", headers={"xi-api-key": API_KEY})
    with urllib.request.urlopen(request, timeout=30) as response:
        d = json.load(response)
    return "tier=%s used=%s limit=%s remaining=%s" % (d.get("tier"), d.get("character_count"), d.get("character_limit"),
        int(d.get("character_limit", 0)) - int(d.get("character_count", 0)))


def generate(sound_id: str) -> str:
    prompt, duration, loop, _peak = SOUNDS[sound_id]
    cache_file = os.path.join(CACHE, sound_id + ".pcm")
    if os.path.exists(cache_file):
        return "cached"
    text = prompt if sound_id.startswith("music") else STYLE + prompt
    body = {"text": text, "duration_seconds": duration, "prompt_influence": 0.7, "loop": loop, "model_id": "eleven_text_to_sound_v2"}
    request = urllib.request.Request(URL, data=json.dumps(body).encode(), method="POST", headers={
        "xi-api-key": API_KEY, "Content-Type": "application/json"})
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
    args = load_key(sys.argv[1:])
    if not API_KEY:
        print("No API key: pass --key-file PATH or set ELEVENLABS_API_KEY")
        return 1
    if "--credits" in args:
        print(credits())
        return 0
    os.makedirs(CACHE, exist_ok=True)
    ids = args or list(SOUNDS)
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
