from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


WIDTH = 1280
HEIGHT = 720
BACKGROUND = (15, 17, 20)
FOREGROUND = (235, 238, 242)
MUTED = (150, 158, 168)
ACCENT = (91, 188, 255)
SUCCESS = (113, 205, 126)
PROMPT = (105, 180, 255)

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "docs" / "images" / "typevault-demo.gif"
FONT_DIR = Path("/usr/share/fonts/truetype/dejavu")
MONO = FONT_DIR / "DejaVuSansMono.ttf"

FONT = ImageFont.truetype(MONO, 29)
SMALL_FONT = ImageFont.truetype(MONO, 25)
TITLE_FONT = ImageFont.truetype(MONO, 34)

SceneLine = tuple[str, str]

SCENES: list[list[SceneLine]] = [
    [
        ("prompt", r"PS C:\Users\Bruno> .\TypeVault.ps1"),
        ("title", "TypeVault 1.7.0"),
        ("plain", "Secure credential typing with Windows Hello"),
        ("plain", ""),
        ("plain", "[1] Type credential"),
        ("plain", "[2] Add credential"),
        ("plain", "[3] List credentials"),
        ("plain", "[4] Change password"),
        ("plain", "[5] Remove credential"),
        ("plain", "[6] Authentication status  [Windows Hello]"),
        ("plain", "[7] Test TypeVault"),
        ("plain", "[8] Test Windows Hello"),
        ("plain", "[0] Exit"),
    ],
    [
        ("prompt", "Select an option: 1"),
        ("plain", ""),
        ("plain", "Available profiles:"),
        ("plain", "  1. GitHub Demo"),
        ("plain", "  2. Work Demo"),
        ("prompt", "Select profile: 1"),
        ("plain", ""),
        ("plain", "Profile selected: GitHub Demo"),
    ],
    [
        ("plain", ""),
        ("plain", "Windows Hello verification required."),
        ("plain", "Authenticating with the configured verifier..."),
        ("success", "Windows Hello: Verified"),
        ("plain", ""),
        ("plain", "Credential remains protected until authentication succeeds."),
    ],
    [
        ("plain", ""),
        ("plain", "Target window capture will occur after the delay."),
        ("plain", "Waiting 3 seconds before target-window capture..."),
        ("plain", "3..."),
        ("plain", "2..."),
        ("plain", "1..."),
        ("plain", ""),
        ("success", "Target window captured."),
    ],
    [
        ("plain", ""),
        ("plain", "Checking foreground window..."),
        ("success", "Foreground window verified."),
        ("plain", ""),
        ("plain", "Preparing Unicode keyboard input via Win32 SendInput..."),
        ("plain", "Input structure validated."),
    ],
    [
        ("plain", ""),
        ("plain", "Destination field is active."),
        ("plain", ""),
        ("plain", "Sending simulated credential input..."),
        ("plain", "Unicode keyboard events dispatched via SendInput."),
        ("success", "Credential typed successfully."),
    ],
    [
        ("plain", ""),
        ("plain", "Press Enter? [Y/N]: Y"),
        ("plain", ""),
        ("plain", "Checking foreground window again..."),
        ("success", "Foreground window verified again."),
        ("success", "Enter sent successfully."),
    ],
    [
        ("plain", ""),
        ("title", "TypeVault security checks"),
        ("plain", "Windows Hello gate: PASS"),
        ("plain", "Foreground verification: PASS"),
        ("plain", "Native input structure: PASS"),
        ("plain", "Stored credential decrypted only after authentication: PASS"),
    ],
    [
        ("plain", ""),
        ("title", "What the demo represents"),
        ("plain", "The target window is captured only after the delay."),
        ("plain", "Foreground state is checked before keyboard input."),
        ("plain", "Foreground state is checked again before Enter."),
        ("plain", "The input path uses Unicode Win32 SendInput events."),
    ],
    [
        ("plain", ""),
        ("title", "Credential safety"),
        ("plain", "Demo profile: GitHub Demo"),
        ("plain", "Credential value: simulated / not real"),
        ("plain", "No real secret is embedded in this animation."),
        ("plain", ""),
        ("success", "Demo complete."),
    ],
    [
        ("prompt", r"PS C:\Users\Bruno> git status"),
        ("plain", ""),
        ("plain", "On branch main"),
        ("plain", "working tree clean"),
        ("plain", ""),
        ("success", "TypeVault demo finished."),
    ],
    [
        ("prompt", r"PS C:\Users\Bruno> _"),
    ],
]

def render_scene(lines: list[SceneLine]) -> Image.Image:
    image = Image.new("RGB", (WIDTH, HEIGHT), BACKGROUND)
    draw = ImageDraw.Draw(image)
    draw.rectangle((0, 0, WIDTH, 54), fill=(27, 30, 35))
    for x, colour in ((28, (210, 90, 86)), (48, (224, 176, 72)), (68, (91, 183, 105))):
        draw.ellipse((x - 6, 13, x + 6, 25), fill=colour)
    draw.text((100, 13), "TypeVault Demo", font=SMALL_FONT, fill=MUTED)
    y = 80
    for kind, text in lines:
        if y > HEIGHT - 42:
            break
        font = TITLE_FONT if kind == "title" else FONT
        colour = ACCENT if kind == "title" else PROMPT if kind == "prompt" else SUCCESS if kind == "success" else FOREGROUND
        draw.text((36, y), text, font=font, fill=colour)
        y += 47 if kind == "title" else 43
    return image

def main() -> None:
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    frames = [render_scene(scene) for scene in SCENES]
    frames[0].save(OUTPUT, save_all=True, append_images=frames[1:], duration=1100, loop=0, optimize=True, disposal=2)

if __name__ == "__main__":
    main()
