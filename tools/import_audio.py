#!/usr/bin/env python3
"""Builds the game's sounds and music (assets/audio/*.ogg) from the sound
libraries kept next to the repo (../Assets by default): picks, trims, levels
and converts each one to Ogg Vorbis.

    python3 tools/import_audio.py [--assets ../Assets] [--only hit,boom]

Each entry of SOUNDS is a game sound: one recipe makes name.ogg, several
make name_1.ogg, name_2.ogg ... for the game to pick from at random. A
recipe is a source (a glob under the assets folder; the first match is used)
and what to do with it:

    start, end   seconds to keep of the source
    length       at most this long (faded out at the end)
    fade         the fade-out at the end, in seconds (default 0.03)
    gain         dB, after the loudest peak is brought to -1 dBFS

Each entry of MUSIC is a track made of Ovani's three layers (Intensity 1,
Intensity 2 and Main: the same piece, sparse to full) as music_name_1.ogg,
_2.ogg and _3.ogg, each looped seamlessly: the reverb tail past the loop point
is folded back over the start. The game plays the layers together and moves
between them with how many things are after you (Audio.heat). LOOPS are the
same for a single sound that loops: name.ogg.
Needs ffmpeg.
"""

import argparse
import glob
import os
import re
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HERE)
OUT = os.path.join(REPO, "assets", "audio")

S = "Sounds"
RETRO = f"{S}/Retro Gaming Sound FX Pack/Retro/16 Bit/**"
RETRO8 = f"{S}/Retro Gaming Sound FX Pack/Retro/8 bit/**"
GOTHIC = f"{S}/Gothic Fantasy Sound FX Pack Vol. 1/Gothic Fantasy Sound FX Pack Vol. 1"
BLAST = f"{S}/Explosives Sound FX Pack/Explosives"
FIRE = f"{S}/Fire Sound FX Pack Vol. 1/Fire Sound FX Pack Vol. 1"
METAL = f"{S}/Metal Sound FX Pack/Metal Sound FX Pack"
EARTH = f"{S}/Earth Sound FX Pack/Earth"
COW = f"{S}/FilmCow Recorded SFX"
COW_D = f"{S}/FilmCow Designed SFX"
FOLEY = f"{S}/Foley Inventory Sound FX Pack/Foley Inventory and Interactions"
COZY = f"{S}/Cozy Casual Sound FX Pack Vol. 1/Cozy Casual Sound FX Pack Vol. 1"
HOLLY = f"{S}/Hollywood Action Sound FX Pack/Hollywood Action"
BODY = f"{S}/Body Horror Sound FX Pack/Body Horror"
AIR = f"{S}/Air Sound FX Pack/Air"
ANIMALS = f"{S}/Animals Sound FX Pack/Animals Sound FX Pack"
FANTASY = f"{S}/Fantasy Music Pack Vol. 2/Fantasy vol 2"
EPIC = f"{S}/Epic Music Pack/Epic Music Pack"
ORCH = f"{S}/Orchestral Ambient Music Pack Vol. 1/Orchestral Ambient Music Pack Vol. 1"

SOUNDS = {
    # --- the ranger -------------------------------------------------------------------------------
    "bow": [{"src": f"{GOTHIC}/Combat/Silver Crossbow 00{n}.wav", "length": 0.3, "fade": 0.12, "gain": -3.0} for n in (1, 2, 3, 4)],
    "bow_heavy": [{"src": f"{GOTHIC}/Combat/Fate Shot 00{n}.wav", "length": 0.5, "fade": 0.15} for n in (1, 2)],
    "draw": {"src": f"{FOLEY}/Pick Up Item/Pick Up Arrows A.wav", "length": 0.4},
    "dry": {"src": f"{S}/Steampunk Sound FX Pack Vol. 1/Steampunk Sound FX Pack Vol. 1/Weapons/Gun Gear Click.wav", "length": 0.25},
    "stance": {"src": f"{FOLEY}/Pick Up Item/Pick Up Equipment C.wav", "length": 0.3},
    "roll": [{"src": f"{RETRO}/Dash 00{n}.wav", "length": 0.3, "gain": -6.0} for n in (1, 8)],
    "hurt": [{"src": f"{COW}/body hit with grunt {n}.wav", "length": 0.6, "fade": 0.1} for n in (1, 2)],
    "lamp_out": {"src": f"{FIRE}/Sizzle/Extinguish A.wav", "length": 1.6, "fade": 0.4},
    "flare": {"src": f"{BLAST}/Realistic/Flashbang Grenade 001.wav", "length": 0.8, "fade": 0.3, "gain": -4.0},
    "wisp": {"src": f"{RETRO}/Range Attack 002.wav", "length": 0.25, "gain": -4.0},
    # --- hitting things ---------------------------------------------------------------------------
    "hit": [{"src": f"{COW}/punch soft thud {n}.wav", "length": 0.18, "gain": -2.0} for n in (1, 3, 4, 6)],
    "kill": [{"src": f"{BODY}/Flesh Tailor/{n}.wav", "length": 0.35, "fade": 0.1, "gain": -3.0} for n in ("Fleshy Slap", "Pulverize A", "Pulverize B")],
    "thud": [{"src": f"{HOLLY}/Weapon/Misc/Bullet Impact {n}.wav", "length": 0.2, "gain": -5.0} for n in ("B", "D", "E")],
    "ricochet": {"src": f"{METAL}/Hits/High Metal Ting C.wav", "length": 0.25, "gain": -4.0},
    "glance": {"src": f"{METAL}/Hits/Metal Doing D.wav", "length": 0.2, "gain": -4.0},
    "clang": {"src": f"{METAL}/Hits/Metal Impact Medium C.wav", "length": 0.5, "fade": 0.15},
    # --- blowing things up ------------------------------------------------------------------------
    "boom": [{"src": f"{BLAST}/Realistic/Dynamite Close 00{n}.wav", "length": 1.3, "fade": 0.5} for n in (1, 2, 3, 4)],
    "big_boom": {"src": f"{BLAST}/Realistic/Megaton Near 001.wav", "length": 3.5, "fade": 1.2},
    "whoomp": [{"src": f"{FIRE}/Fire Magic/{n}.wav", "length": 0.7, "fade": 0.25, "gain": -2.0} for n in ("Fire Impact A", "Monster Fire Short A")],
    "fuse": {"src": f"{BLAST}/Fuse/Dynamite Fuse Start 001.wav", "length": 0.7, "fade": 0.1},
    "crumble": [{"src": f"{EARTH}/Stones/Crumbling Rock {n}.wav", "length": 1.0, "fade": 0.3} for n in "ABC"],
    # --- what's lying around ----------------------------------------------------------------------
    "crate_hit": {"src": f"{S}/Foley Props Sound FX Pack/Foley Props/Containers and Keys/Wooden Crate Impact Normal.wav", "length": 0.2, "gain": -3.0},
    "crate_break": [{"src": f"{COZY}/Wood and Stone/Wood Break {n}.wav", "length": 0.6, "fade": 0.2} for n in "ABC"],
    "ore_hit": {"src": f"{FOLEY}/Pick Up Item/Pick Up Stone C.wav", "length": 0.2},
    "cart_hit": {"src": f"{METAL}/Hits/Metal Impact Heavy C.wav", "length": 0.5, "fade": 0.2},
    "chest": {"src": f"{FOLEY}/Pick Up Item/Pick Up Metal B.wav", "length": 0.8, "fade": 0.3},
    "nugget": [{"src": f"{FOLEY}/Pick Up Item/Pick Up Metal {n}.wav", "length": 0.18, "gain": -3.0} for n in "CEG"],
    "powder": {"src": f"{FOLEY}/Pick Up Item/Pick Up Equipment D.wav", "length": 0.3},
    "oil": {"src": f"{FOLEY}/Pick Up Item/Pick Up Bottle C.wav", "length": 0.5, "fade": 0.15},
    "perk": {"src": f"{GOTHIC}/Environment/Ether Bells 002.wav", "length": 1.6, "fade": 0.7, "gain": -4.0},
    # --- what lives down here ---------------------------------------------------------------------
    "rat": [{"src": f"{ANIMALS}/Non Loops/Domestic/Rat Squeak {n}.wav", "length": 0.4, "fade": 0.1} for n in "ABCD"],
    "bat": {"src": f"{ANIMALS}/Non Loops/Domestic/Rat Squeak E.wav", "length": 0.3},
    "miner_grunt": [{"src": f"{GOTHIC}/Creatures/Ghoul Bite 00{n}.wav", "length": 0.5, "fade": 0.15, "gain": -4.0} for n in (1, 2)],
    "swing": {"src": f"{S}/Foley Movement Vol. 1/Foley Movement Vol. 1/Whoosh/*.wav", "length": 0.3},
    "spit": [{"src": f"{COW_D}/goo {n}.wav", "length": 0.35, "fade": 0.1} for n in (1, 3, 4)],
    "squelch": [{"src": f"{COW_D}/goo {n}.wav", "length": 0.5, "fade": 0.15} for n in (6, 8, 10)],
    "whistle": {"src": f"{S}/Foley Sports Sound FX Pack/Foley Sports/Whistle/Whistle Short Blow.wav", "length": 0.6, "fade": 0.2, "gain": -4.0},
    "throw": {"src": f"{FOLEY}/Drop Item/Drop Arrows A.wav", "length": 0.25},
    "ember": {"src": f"{FIRE}/Fire Movement/Fire Whip A.wav", "length": 0.4, "fade": 0.15},
    "beetle": {"src": f"{COW_D}/bug people 2.wav", "length": 0.5, "fade": 0.15},
    "splash": [{"src": f"{COW}/splash {n}.wav", "length": 0.5, "fade": 0.2, "gain": -2.0} for n in (8, 12, 14)],
    "shard": {"src": f"{METAL}/Hits/High Metal Ting C.wav", "length": 0.2, "gain": -6.0},
    "shatter": {"src": f"{S}/Foley Props Sound FX Pack/Foley Props/Kitchen/Breaking Glass Shatter.wav", "length": 0.8, "fade": 0.3},
    "bones": [{"src": f"{BODY}/Bones and Breaks/{n}.wav", "length": 0.5, "fade": 0.15} for n in ("Simple Bone Snap B", "Body Crackle")],
    "wraith": [{"src": f"{AIR}/Ghostly/Ghost Breath {n}.wav", "length": 0.8, "fade": 0.3} for n in "AC"],
    "snuff": {"src": f"{FIRE}/Sizzle/Extinguish B.wav", "length": 0.5, "fade": 0.2},
    # --- the big ones -----------------------------------------------------------------------------
    "roar": [{"src": f"{GOTHIC}/Creatures/Werewolf Attack 001.wav", "length": 1.2, "fade": 0.4}],
    "stomp": [{"src": f"{GOTHIC}/Combat/Medieval Stomp 00{n}.wav", "length": 0.5, "fade": 0.2} for n in (1, 2, 3)],
    "quake": [{"src": f"{EARTH}/Underground/Earthquake Impacts {n}.wav", "length": 1.0, "fade": 0.4} for n in "AF"],
    "rumble": {"src": f"{EARTH}/Underground/Earthquake Short A.wav", "length": 2.0, "fade": 0.8},
    "dark": [{"src": f"{GOTHIC}/Spells And Abilities/Into The Darkness 00{n}.wav", "length": 1.6, "fade": 0.5} for n in (1, 5)],
    "banish": {"src": f"{GOTHIC}/Spells And Abilities/Banish 002.wav", "length": 1.2, "fade": 0.4},
    "heartbeat": {"src": f"{BODY}/Flesh Tailor/Fleshy Slap.wav", "length": 0.3, "fade": 0.1, "gain": -2.0},
    "boss_die": {"src": f"{GOTHIC}/Creatures/Werewolf Death 001.wav", "length": 2.0, "fade": 0.7},
    # --- the mine ---------------------------------------------------------------------------------
    "bell": {"src": f"{GOTHIC}/Environment/Ghostly Bell 005.wav", "length": 3.0, "fade": 1.2, "gain": -2.0},
    "cage_arrive": {"src": f"{S}/Steampunk Sound FX Pack Vol. 1/Steampunk Sound FX Pack Vol. 1/Ambience and Loops/Metal Creak Short A.wav", "length": 1.0, "fade": 0.4},
    "cage_down": {"src": f"{S}/Steampunk Sound FX Pack Vol. 1/Steampunk Sound FX Pack Vol. 1/Ambience and Loops/Metal Creak Long B.wav", "length": 1.6, "fade": 0.6},
    "death_sting": {"src": f"{FANTASY}/Death (RT 5.143)/Fantasy Vol2 Death Cut 30.wav", "length": 16.0, "fade": 4.0, "gain": -4.0},
    # --- menus ------------------------------------------------------------------------------------
    "tick": {"src": f"{COZY}/Abstracts/Menu A.wav", "length": 0.15, "gain": -4.0},
    "accept": {"src": f"{COZY}/Abstracts/Menu C.wav", "length": 0.4, "fade": 0.1},
}

MUSIC = {
    "title": f"{FANTASY}/Mysterious Exploration*",
    "mine": f"{FANTASY}/Evil Cave*",
    "deep": f"{EPIC}/Underworld*",
    "boss": f"{FANTASY}/Small Boss*",
    "final": f"{EPIC}/Bully*",
    "ending": f"{ORCH}/Rest Now*",
}

# A single sound that loops as it is: [source, 0, 0]; or [source, seconds to take, seconds folded back over the start]
LOOPS = {
    "ambient_mine": [f"{EARTH}/Underground/Shifting Cavern Ambience Loop.wav", 0.0, 0.0],
}


def assets_folder(given: str) -> str:
    if os.path.isdir(given):
        return given
    # In a worktree, the assets are beside the main checkout.
    folder = REPO
    while folder != os.path.dirname(folder):
        folder = os.path.dirname(folder)
        if os.path.isdir(os.path.join(folder, "Assets")):
            return os.path.join(folder, "Assets")
    raise SystemExit(f"No assets at {given}")


def find(assets: str, pattern: str) -> str:
    # Library folders are full of glob characters of their own, like [ and ].
    matches = sorted(glob.glob(os.path.join(glob.escape(assets), pattern), recursive=True))
    matches = [m for m in matches if "__MACOSX" not in m]
    if not matches:
        raise SystemExit(f"Not found: {pattern}")
    return matches[0]


def peak_db(path: str, filters: str) -> float:
    result = subprocess.run(["ffmpeg", "-hide_banner", "-i", path, "-af", filters + ",volumedetect", "-f", "null", "-"],
        capture_output=True, text=True)
    match = re.search(r"max_volume: (-?[\d.]+) dB", result.stderr)
    return float(match.group(1)) if match else 0.0


def make_sound(assets: str, recipe: dict, out: str) -> None:
    src = find(assets, recipe["src"])
    filters = ["aformat=channel_layouts=mono"]
    start, end = recipe.get("start"), recipe.get("end")
    if start is not None or end is not None:
        filters.append(f"atrim=start={start or 0}" + (f":end={end}" if end is not None else "") + ",asetpts=PTS-STARTPTS")
    # Trims the silence a library leaves in front of a hit, so it lands on the frame.
    filters.append("silenceremove=start_periods=1:start_threshold=-50dB")
    length = recipe.get("length")
    fade = recipe.get("fade", 0.03)
    if length:
        filters.append(f"atrim=end={length},afade=t=out:st={max(length - fade, 0)}:d={fade}")
    chain = ",".join(filters)
    gain = -1.0 - peak_db(src, chain) + recipe.get("gain", 0.0)
    subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-i", src, "-af", f"{chain},volume={gain:.2f}dB",
        "-ar", "44100", "-c:a", "libvorbis", "-q:a", "4", out], check=True)


def make_music(assets: str, folder_glob: str, name: str) -> None:
    folder = find(assets, folder_glob)
    tail = float(re.search(r"RT ([\d.]+)", folder).group(1))
    for i, layer in enumerate(["Intensity 1", "Intensity 2", "Main"]):
        src = glob.glob(os.path.join(glob.escape(folder), f"* {layer}.wav"))[0]
        duration = float(subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", src],
            capture_output=True, text=True).stdout)
        loop = duration - tail
        graph = (f"[0]atrim=0:{loop},asetpts=PTS-STARTPTS[body];"
            f"[0]atrim={loop},asetpts=PTS-STARTPTS[tail];"
            "[body][tail]amix=inputs=2:duration=first:normalize=0[out]")
        out = os.path.join(OUT, f"music_{name}_{i + 1}.ogg")
        subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-i", src, "-filter_complex", graph, "-map", "[out]",
            "-ar", "44100", "-c:a", "libvorbis", "-q:a", "3", out], check=True)
        print(f"  {os.path.basename(out)} ({loop:.1f} s)")


def make_loop(assets: str, spec: list, name: str) -> None:
    src = find(assets, spec[0])
    seconds, tail = spec[1], spec[2]
    if seconds <= 0.0:
        subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-i", src, "-ar", "44100", "-c:a", "libvorbis", "-q:a", "2", os.path.join(OUT, f"{name}.ogg")], check=True)
        return
    graph = (f"[0]atrim=0:{seconds},asetpts=PTS-STARTPTS[body];"
        f"[0]atrim={seconds}:{seconds + tail},asetpts=PTS-STARTPTS,afade=t=out:st=0:d={tail}[tail];"
        "[body][tail]amix=inputs=2:duration=first:normalize=0[out]")
    subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-i", src, "-filter_complex", graph, "-map", "[out]",
        "-ar", "44100", "-c:a", "libvorbis", "-q:a", "2", os.path.join(OUT, f"{name}.ogg")], check=True)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--assets", default=os.path.join(REPO, "..", "Assets"))
    parser.add_argument("--only", default="", help="comma-separated names to make (sounds or music)")
    args = parser.parse_args()
    assets = assets_folder(args.assets)
    only = set(filter(None, args.only.split(",")))
    os.makedirs(OUT, exist_ok=True)
    for name, recipes in SOUNDS.items():
        if only and name not in only:
            continue
        if isinstance(recipes, dict):
            make_sound(assets, recipes, os.path.join(OUT, f"{name}.ogg"))
        else:
            for i, recipe in enumerate(recipes):
                make_sound(assets, recipe, os.path.join(OUT, f"{name}_{i + 1}.ogg"))
        print(name)
    for name, folder in MUSIC.items():
        if only and name not in only:
            continue
        print(f"music {name}")
        make_music(assets, folder, name)
    for name, spec in LOOPS.items():
        if only and name not in only:
            continue
        make_loop(assets, spec, name)
        print(name)


if __name__ == "__main__":
    sys.exit(main())
