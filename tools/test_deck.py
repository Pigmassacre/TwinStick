#!/usr/bin/env python3
"""Plays the game the way a Steam Deck does: pretending to be one, at its
resolution, from the title onwards, with nothing but a controller. The controller
is real as far as the game can tell: a virtual Steam Virtual Gamepad, made with
/dev/uinput, as Steam Input presents the Deck's own controls.

    python3 tools/test_deck.py [--size 1280x800] [--godot path]

Needs write access to /dev/uinput, and a display. Quits with 1 if anything failed.
"""
import argparse
import fcntl
import json
import os
import struct
import subprocess
import sys
import threading
import time

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HERE)

EV_SYN, EV_KEY, EV_ABS = 0, 1, 3
UI_SET_EVBIT, UI_SET_KEYBIT, UI_SET_ABSBIT = 0x40045564, 0x40045565, 0x40045567
UI_DEV_SETUP, UI_ABS_SETUP, UI_DEV_CREATE, UI_DEV_DESTROY = 0x405c5503, 0x401c5504, 0x5501, 0x5502
A, B, X, Y, LB, RB, BACK, START, GUIDE, L3, R3 = 0x130, 0x131, 0x133, 0x134, 0x136, 0x137, 0x13a, 0x13b, 0x13c, 0x13d, 0x13e
LX, LY, LT, RX, RY, RT, HATX, HATY = 0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x10, 0x11


class Pad:
    def __init__(self):
        self.fd = os.open("/dev/uinput", os.O_WRONLY | os.O_NONBLOCK)
        fcntl.ioctl(self.fd, UI_SET_EVBIT, EV_KEY)
        for key in (A, B, X, Y, LB, RB, BACK, START, GUIDE, L3, R3):
            fcntl.ioctl(self.fd, UI_SET_KEYBIT, key)
        fcntl.ioctl(self.fd, UI_SET_EVBIT, EV_ABS)
        for axis, low, high in ((LX, -32768, 32767), (LY, -32768, 32767), (RX, -32768, 32767), (RY, -32768, 32767),
                (LT, 0, 255), (RT, 0, 255), (HATX, -1, 1), (HATY, -1, 1)):
            fcntl.ioctl(self.fd, UI_SET_ABSBIT, axis)
            fcntl.ioctl(self.fd, UI_ABS_SETUP, struct.pack("<HH6i", axis, 0, 0, low, high, 0, 0, 0))
        # Steam's virtual controller: bus USB, Valve, product 0x11ff.
        fcntl.ioctl(self.fd, UI_DEV_SETUP, struct.pack("<4H80sI", 3, 0x28de, 0x11ff, 1, b"Steam Virtual Gamepad", 0))
        fcntl.ioctl(self.fd, UI_DEV_CREATE)
        time.sleep(0.5)

    def _send(self, kind, code, value):
        os.write(self.fd, struct.pack("<qqHHi", 0, 0, kind, code, value))

    def _sync(self):
        self._send(EV_SYN, 0, 0)

    def press(self, key, hold=0.1):
        self._send(EV_KEY, key, 1)
        self._sync()
        time.sleep(hold)
        self._send(EV_KEY, key, 0)
        self._sync()
        time.sleep(0.25)

    def axis(self, axis, value):
        self._send(EV_ABS, axis, value)
        self._sync()

    def close(self):
        fcntl.ioctl(self.fd, UI_DEV_DESTROY)
        os.close(self.fd)


def find_godot():
    if os.environ.get("GODOT"):
        return os.environ["GODOT"]
    folder = REPO
    while folder != os.path.dirname(folder):
        folder = os.path.dirname(folder)
        path = os.path.join(folder, "Godot", "Godot_v4.7.2-stable_linux.x86_64")
        if os.path.isfile(path):
            return path
    raise SystemExit("No Godot found: set GODOT")


class Game:
    def __init__(self, godot, size):
        self.state = {}
        # Steam sets this for what it launches: SDL ignores its virtual controller otherwise.
        env = dict(os.environ, SDL_GAMECONTROLLER_ALLOW_STEAM_VIRTUAL_GAMEPAD="1")
        self.proc = subprocess.Popen([godot, "--path", REPO, "--", "--deck", "--no-save", "--pad-log", "--invincible", f"--size={size}", "--seed=5"],
            env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
        self.errors = []
        threading.Thread(target=self._read, daemon=True).start()

    def _read(self):
        for line in self.proc.stdout:
            if line.startswith("PAD "):
                self.state = json.loads(line[4:])
            elif "SCRIPT ERROR" in line:
                self.errors.append(line.strip())

    def get(self, key, default=None):
        return self.state.get(key, default)

    def settle(self, seconds=0.45):
        time.sleep(seconds)


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--size", default="1280x800")
    args = parser.parse_args()
    failures = []

    def check(what, ok, extra=""):
        print(("ok   " if ok else "FAIL ") + what + (f"  ({extra})" if extra != "" else ""))
        if not ok:
            failures.append(what)

    pad = Pad()
    game = Game(find_godot(), args.size)
    try:
        for _ in range(40):
            time.sleep(0.25)
            if game.get("screen") == "title":
                break
        time.sleep(1.0)
        s = game.state
        width, height = (int(v) for v in args.size.split("x"))
        check("found the pad", len(s.get("pads", [])) > 0, s.get("pads"))
        check("knows it's a Deck, and starts on the pad", s.get("deck") and s.get("device") == "PAD", s.get("device"))
        scale = s.get("scale", 0)
        check("draws at a whole-number scale", scale == int(scale) and scale == min(width // 384, height // 216), scale)
        game_w, game_h = (float(v) for v in s["game"].strip("()").split(","))
        check("fills the window", width - game_w * scale <= scale and height - game_h * scale <= scale, f'{s["game"]} x{scale}')
        check("the prompts name its buttons", s.get("prompt") == "L1", s.get("prompt"))
        check("a button has the focus", s.get("focus") == "Go down", s.get("focus"))
        # Through the menu, by stick and d-pad.
        pad.axis(LY, 32767)
        game.settle(0.3)
        pad.axis(LY, 0)
        game.settle()
        check("the stick moves down the menu", game.get("focus") == "The Daily Shift", game.get("focus"))
        pad.axis(HATY, -1)
        game.settle(0.15)
        pad.axis(HATY, 0)
        game.settle()
        check("the d-pad moves up it", game.get("focus") == "Go down", game.get("focus"))
        # Down the mine: A, and A through the words on the way.
        pad.press(A)
        game.settle(1.2)
        check("A starts the game", game.get("screen") == "play", game.get("screen"))
        for _ in range(5):
            pad.press(A)
        for _ in range(20):
            if game.get("x") is not None:
                break
            time.sleep(0.25)
        game.settle(1.5)
        # Walking.
        before = game.get("x")
        pad.axis(LX, -32767)
        game.settle(0.7)
        pad.axis(LX, 0)
        game.settle()
        walked = abs((game.get("x") or 0) - (before or 0))
        before = game.get("x")
        pad.axis(LX, 32767)
        game.settle(0.7)
        pad.axis(LX, 0)
        game.settle()
        walked = max(walked, abs((game.get("x") or 0) - (before or 0)))
        check("the left stick walks", walked > 15, f"{walked:.0f} px")
        check("the bow follows the walking", abs(game.get("aim_x", 0)) > 0.5, game.get("aim_x"))
        # Shooting with the right stick.
        pad.axis(RX, 0)
        pad.axis(RY, -32767)
        game.settle(0.5)
        check("the right stick aims", game.get("aim_y", 0) < -0.5, game.get("aim_y"))
        check("and shoots", game.get("firing") is True, game.get("firing"))
        pad.axis(RY, 0)
        game.settle()
        check("letting go stops", game.get("firing") is False, game.get("firing"))
        # The trigger.
        pad.axis(RT, 255)
        game.settle(0.4)
        check("the right trigger shoots", game.get("firing") is True, game.get("firing"))
        pad.axis(RT, 0)
        game.settle()
        # Demolition.
        pad.press(LB)
        game.settle(0.3)
        check("L1 changes stance", game.get("stance") == 1, game.get("stance"))
        powder = game.get("powder")
        pad.axis(RX, 14000)
        game.settle(0.9)
        check("in Demolition, half a push only aims", game.get("powder") == powder, f'{powder} -> {game.get("powder")}')
        pad.axis(RX, 32767)
        game.settle(1.5)
        check("all the way throws one, however long it's held", game.get("powder") == powder - 1, f'{powder} -> {game.get("powder")}')
        pad.axis(RX, 0)
        game.settle(0.4)
        pad.axis(RX, 32767)
        game.settle(0.4)
        check("and another push another", game.get("powder") == powder - 2, f'{powder} -> {game.get("powder")}')
        pad.axis(RX, 0)
        game.settle(0.3)
        pad.press(LB)
        game.settle(0.3)
        # Rolling.
        pad.press(RB, 0.05)
        check("R1 rolls", game.get("rolled") is True, game.get("rolled"))
        game.settle(1.2)
        pad.axis(LT, 255)
        game.settle(0.1)
        pad.axis(LT, 0)
        game.settle(0.2)
        check("so does the left trigger", game.get("rolled") is True, game.get("rolled"))
        # The pause menu.
        pad.press(START)
        game.settle()
        check("Menu pauses", game.get("paused") is True, game.get("paused"))
        check("a pause button has the focus", game.get("focus") == "Carry on", game.get("focus"))
        pad.press(B)
        game.settle()
        check("B carries on", game.get("paused") is False, game.get("paused"))
        check("nothing broke", not game.errors, game.errors[:3])
        # The controller going away.
        pad.close()
        pad = None
        game.settle(1.0)
        check("losing the pad pauses", game.get("paused") is True, game.get("paused"))
    finally:
        game.proc.terminate()
        try:
            game.proc.wait(timeout=5)
        except subprocess.TimeoutExpired:
            game.proc.kill()
        if pad:
            pad.close()
    print(f"{len(failures)} failures")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
