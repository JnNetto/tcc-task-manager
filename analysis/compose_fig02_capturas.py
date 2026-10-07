#!/usr/bin/env python3
"""Monta a Figura 2 — capturas em uma única linha.

Ordem: online-lista | offline-lista | online-form | offline-form
  — em cima: Online-first / Offline-first
  — embaixo: Lista de tarefas / Formulário

Uso:
  python compose_fig02_capturas.py --compose
  python compose_fig02_capturas.py --compose --width 280
"""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

C_ONLINE = (44, 95, 138)
C_OFFLINE = (46, 125, 79)
C_MUTED = (107, 114, 128)
C_BG = (255, 255, 255)
C_SLOT = (229, 231, 235)
C_SLOT_EDGE = (156, 163, 175)

PHONE_DISPLAY_W = 300
GAP_X = 14
PAIR_GAP = 28  # folga entre o par "lista" e o par "formulário"
MARGIN_X = 14
MARGIN_TOP = 40
MARGIN_BOTTOM = 16
LABEL_GAP = 6


def _font(size: int, bold: bool = False) -> ImageFont.ImageFont:
    candidates = [
        "C:/Windows/Fonts/segoeuib.ttf" if bold else "C:/Windows/Fonts/segoeui.ttf",
        "C:/Windows/Fonts/arialbd.ttf" if bold else "C:/Windows/Fonts/arial.ttf",
        "DejaVuSans-Bold.ttf" if bold else "DejaVuSans.ttf",
    ]
    for path in candidates:
        try:
            return ImageFont.truetype(path, size=size)
        except OSError:
            continue
    return ImageFont.load_default()


def _load(path: Path | None) -> Image.Image | None:
    if path is None or not path.is_file():
        return None
    with Image.open(path) as im:
        return im.convert("RGB")


def _resize_phone(im: Image.Image, target_w: int) -> Image.Image:
    w, h = im.size
    target_h = max(1, round(h * (target_w / w)))
    return im.resize((target_w, target_h), Image.Resampling.LANCZOS)


def _placeholder(w: int, h: int, text: str) -> Image.Image:
    im = Image.new("RGB", (w, h), C_SLOT)
    draw = ImageDraw.Draw(im)
    draw.rectangle([2, 2, w - 3, h - 3], outline=C_SLOT_EDGE, width=2)
    font = _font(14)
    bbox = draw.textbbox((0, 0), text, font=font)
    tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
    draw.text(((w - tw) / 2, (h - th) / 2), text, fill=C_MUTED, font=font, align="center")
    return im


def _text_size(draw: ImageDraw.ImageDraw, text: str, font: ImageFont.ImageFont) -> tuple[int, int]:
    bbox = draw.textbbox((0, 0), text, font=font)
    return bbox[2] - bbox[0], bbox[3] - bbox[1]


def compose(
    out_path: Path,
    shots_dir: Path,
    *,
    force_template: bool = False,
) -> Path:
    paths = {
        "online_lista": None if force_template else shots_dir / "online_lista.png",
        "offline_lista": None if force_template else shots_dir / "offline_lista.png",
        "online_form": None if force_template else shots_dir / "online_form.png",
        "offline_form": None if force_template else shots_dir / "offline_form.png",
    }
    imgs = {k: _load(p) for k, p in paths.items()}

    ref = next((im for im in imgs.values() if im is not None), None)
    phone_h = (
        round(PHONE_DISPLAY_W * (1600 / 800))
        if ref is None
        else round(PHONE_DISPLAY_W * (ref.size[1] / ref.size[0]))
    )

    def cell(key: str, placeholder: str) -> Image.Image:
        im = imgs.get(key)
        if im is None:
            return _placeholder(PHONE_DISPLAY_W, phone_h, placeholder)
        return _resize_phone(im, PHONE_DISPLAY_W)

    columns = [
        ("online_lista", "Online-first", C_ONLINE, "Lista de tarefas", "Lista\nonline"),
        ("offline_lista", "Offline-first", C_OFFLINE, "Lista de tarefas", "Lista\noffline"),
        ("online_form", "Online-first", C_ONLINE, "Formulário", "Form\nonline"),
        ("offline_form", "Offline-first", C_OFFLINE, "Formulário", "Form\noffline"),
    ]

    if not force_template and imgs["online_form"] is None and imgs["offline_form"] is None:
        columns = columns[:2]

    n = len(columns)
    gaps = []
    for i in range(n - 1):
        gaps.append(PAIR_GAP if (n == 4 and i == 1) else GAP_X)

    phone_w = PHONE_DISPLAY_W
    header_font = _font(14, bold=True)
    label_font = _font(12)
    tmp_draw = ImageDraw.Draw(Image.new("RGB", (10, 10)))
    _, label_h = _text_size(tmp_draw, "Lista de tarefas", label_font)

    canvas_w = MARGIN_X * 2 + phone_w * n + sum(gaps)
    canvas_h = MARGIN_TOP + phone_h + LABEL_GAP + label_h + MARGIN_BOTTOM
    canvas = Image.new("RGB", (canvas_w, canvas_h), C_BG)
    draw = ImageDraw.Draw(canvas)

    x = MARGIN_X
    for i, (key, arch, color, screen, ph) in enumerate(columns):
        im = cell(key, ph)
        if im.size != (phone_w, phone_h):
            im = im.resize((phone_w, phone_h), Image.Resampling.LANCZOS)

        cx = x + phone_w / 2
        tw, th = _text_size(draw, arch, header_font)
        draw.text((cx - tw / 2, (MARGIN_TOP - th) / 2), arch, fill=color, font=header_font)

        canvas.paste(im, (x, MARGIN_TOP))

        tw, th = _text_size(draw, screen, label_font)
        draw.text(
            (cx - tw / 2, MARGIN_TOP + phone_h + LABEL_GAP),
            screen,
            fill=C_MUTED,
            font=label_font,
        )

        if i < n - 1:
            x += phone_w + gaps[i]

    out_path.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(out_path, format="PNG", optimize=True)
    return out_path


def write_readme(shots_dir: Path) -> None:
    shots_dir.mkdir(parents=True, exist_ok=True)
    (shots_dir / "README.md").write_text(
        """# Screenshots para a Figura 2

Layout final: **uma linha** — online lista | offline lista | online form | offline form.

| Arquivo | Conteúdo |
|---|---|
| `online_lista.png` | Lista — online-first |
| `offline_lista.png` | Lista — offline-first |
| `online_form.png` | Formulário — online |
| `offline_form.png` | Formulário — offline |

```bash
cd analysis
python compose_fig02_capturas.py --compose
```
""",
        encoding="utf-8",
    )


def parse_args(argv=None):
    p = argparse.ArgumentParser(description="Composição da Figura 2 (uma linha).")
    p.add_argument("--compose", action="store_true")
    p.add_argument("--output", default=None)
    p.add_argument("--shots-dir", default=None)
    p.add_argument(
        "--width",
        type=int,
        default=PHONE_DISPLAY_W,
        help=f"Largura de cada captura (default {PHONE_DISPLAY_W}px).",
    )
    return p.parse_args(argv)


def main(argv=None) -> int:
    global PHONE_DISPLAY_W
    args = parse_args(argv)
    PHONE_DISPLAY_W = max(160, int(args.width))

    base = Path(__file__).parent / "output" / "figures"
    shots_dir = Path(args.shots_dir) if args.shots_dir else base / "screenshots"
    write_readme(shots_dir)

    if args.compose:
        out = Path(args.output) if args.output else base / "02_capturas_prototipos.png"
        path = compose(out, shots_dir, force_template=False)
        print(f"Composto: {path}  ({PHONE_DISPLAY_W}px/foto, 1 linha)")
    else:
        out = Path(args.output) if args.output else base / "02_capturas_prototipos_TEMPLATE.png"
        path = compose(out, shots_dir, force_template=True)
        print(f"Template: {path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
