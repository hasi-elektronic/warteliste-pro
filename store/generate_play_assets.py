#!/usr/bin/env python3
"""Generate Google Play Store assets: feature graphic + phone screenshots."""
from PIL import Image, ImageDraw, ImageFont, ImageFilter
import os

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "play_assets")
os.makedirs(OUT, exist_ok=True)
ICON_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "play_store_icon.png")

# Brand colors (Material 3 teal)
TEAL_DARK = (0, 77, 77)
TEAL = (0, 121, 107)
TEAL_LIGHT = (77, 182, 172)
WHITE = (255, 255, 255)
BG_LIGHT = (240, 248, 247)
TEXT_DARK = (33, 33, 33)
TEXT_GREY = (117, 117, 117)
ORANGE = (255, 152, 0)
GREEN = (76, 175, 80)
BLUE = (33, 150, 243)

def font(size, bold=False):
    paths = [
        "/System/Library/Fonts/HelveticaNeue.ttc",
        "/System/Library/Fonts/Helvetica.ttc",
    ]
    for p in paths:
        try:
            return ImageFont.truetype(p, size, index=1 if bold else 0)
        except Exception:
            pass
    return ImageFont.load_default()

def gradient(size, top, bottom):
    w, h = size
    img = Image.new("RGB", size, top)
    pixels = img.load()
    for y in range(h):
        t = y / max(1, h - 1)
        r = int(top[0] * (1 - t) + bottom[0] * t)
        g = int(top[1] * (1 - t) + bottom[1] * t)
        b = int(top[2] * (1 - t) + bottom[2] * t)
        for x in range(w):
            pixels[x, y] = (r, g, b)
    return img

def text_w(draw, txt, fnt):
    bbox = draw.textbbox((0, 0), txt, font=fnt)
    return bbox[2] - bbox[0]

# ----- Feature Graphic 1024x500 -----
def make_feature():
    img = gradient((1024, 500), TEAL_DARK, TEAL)
    d = ImageDraw.Draw(img)

    # Subtle circle decor
    for cx, cy, r, alpha in [(900, 100, 200, 30), (100, 450, 250, 25)]:
        overlay = Image.new("RGBA", img.size, (0, 0, 0, 0))
        od = ImageDraw.Draw(overlay)
        od.ellipse((cx - r, cy - r, cx + r, cy + r), fill=(255, 255, 255, alpha))
        img = Image.alpha_composite(img.convert("RGBA"), overlay).convert("RGB")
    d = ImageDraw.Draw(img)

    # Icon
    try:
        icon = Image.open(ICON_PATH).convert("RGBA").resize((180, 180), Image.LANCZOS)
        img.paste(icon, (70, 160), icon)
    except Exception as e:
        print("icon err", e)

    # Title
    d.text((280, 165), "WarteListe Pro", font=font(64, bold=True), fill=WHITE)
    d.text((280, 245), "Wartelisten-Management", font=font(32), fill=(220, 240, 235))
    d.text((280, 290), "für Logopädie-Praxen", font=font(32), fill=(220, 240, 235))

    # Tagline pill
    pill_text = "Schluss mit Excel-Chaos"
    fnt = font(26, bold=True)
    tw = text_w(d, pill_text, fnt)
    px, py = 280, 360
    d.rounded_rectangle((px, py, px + tw + 40, py + 50), radius=25, fill=ORANGE)
    d.text((px + 20, py + 10), pill_text, font=fnt, fill=WHITE)

    out = os.path.join(OUT, "feature_graphic_1024x500.png")
    img.save(out, "PNG")
    print("wrote", out)

# ----- Phone Screenshot helper -----
PHONE_W, PHONE_H = 1080, 1920

def base_phone(title):
    img = Image.new("RGB", (PHONE_W, PHONE_H), BG_LIGHT)
    d = ImageDraw.Draw(img)
    # Status bar
    d.rectangle((0, 0, PHONE_W, 60), fill=TEAL_DARK)
    d.text((40, 18), "9:41", font=font(28, bold=True), fill=WHITE)
    d.text((PHONE_W - 140, 18), "100%", font=font(26), fill=WHITE)
    # App bar
    d.rectangle((0, 60, PHONE_W, 220), fill=TEAL)
    d.text((50, 110), title, font=font(54, bold=True), fill=WHITE)
    return img, d

def card(d, x, y, w, h, fill=WHITE, shadow=True):
    if shadow:
        for off, alpha in [(6, 30), (3, 60)]:
            d.rounded_rectangle((x + off, y + off, x + w + off, y + h + off), radius=20, fill=(220, 220, 220))
    d.rounded_rectangle((x, y, x + w, y + h), radius=20, fill=fill)

def screenshot_dashboard():
    img, d = base_phone("Dashboard")
    # KPI cards 2x2
    margin = 50
    cw = (PHONE_W - 3 * margin) // 2
    ch = 280
    kpis = [
        ("24", "Wartende", ORANGE),
        ("8", "Platz gefunden", GREEN),
        ("12", "In Behandlung", BLUE),
        ("87%", "Auslastung", TEAL),
    ]
    for i, (val, label, color) in enumerate(kpis):
        cx = margin + (i % 2) * (cw + margin)
        cy = 280 + (i // 2) * (ch + margin)
        card(d, cx, cy, cw, ch)
        # color bar
        d.rounded_rectangle((cx, cy, cx + 12, cy + ch), radius=6, fill=color)
        d.text((cx + 40, cy + 50), val, font=font(110, bold=True), fill=color)
        d.text((cx + 40, cy + 190), label, font=font(34), fill=TEXT_GREY)

    # Bottom chart card
    chx, chy = margin, 1240
    chw, chh = PHONE_W - 2 * margin, 560
    card(d, chx, chy, chw, chh)
    d.text((chx + 40, chy + 30), "Monatliche Aufnahmen", font=font(36, bold=True), fill=TEXT_DARK)
    # bars
    bars = [3, 7, 5, 9, 12, 8, 6]
    bw = 80
    gap = 30
    base_y = chy + chh - 60
    start_x = chx + 60
    for i, h in enumerate(bars):
        bh = h * 30
        bx = start_x + i * (bw + gap)
        d.rounded_rectangle((bx, base_y - bh, bx + bw, base_y), radius=8, fill=TEAL_LIGHT)
    out = os.path.join(OUT, "screenshot_1_dashboard.png")
    img.save(out, "PNG")
    print("wrote", out)

def screenshot_warteliste():
    img, d = base_phone("Warteliste")
    # Tab bar
    d.rectangle((0, 220, PHONE_W, 300), fill=WHITE)
    tabs = ["Alle", "Wartend", "Platz", "Behandl."]
    tw = PHONE_W // len(tabs)
    for i, t in enumerate(tabs):
        x = i * tw
        if i == 1:
            d.rectangle((x, 286, x + tw, 300), fill=TEAL)
        bbox = d.textbbox((0, 0), t, font=font(32, bold=True))
        d.text((x + (tw - (bbox[2] - bbox[0])) // 2, 240), t, font=font(32, bold=True), fill=TEAL if i == 1 else TEXT_GREY)

    # Patient list items
    patients = [
        ("Schröbel, Hans-Dietmar", "Dysphagie", "wartend", "47 Tage", ORANGE),
        ("Müller, Anna", "Stottern", "wartend", "31 Tage", ORANGE),
        ("Wagner, Sophie", "Sprachentwicklung", "wartend", "22 Tage", ORANGE),
        ("Becker, Lukas", "Aphasie", "wartend", "15 Tage", ORANGE),
        ("Hoffmann, Lisa", "Stimmstörung", "wartend", "8 Tage", ORANGE),
    ]
    y = 340
    for name, diagnose, status, wait, color in patients:
        card(d, 50, y, PHONE_W - 100, 230)
        d.rounded_rectangle((50, y, 62, y + 230), radius=6, fill=color)
        d.text((90, y + 30), name, font=font(40, bold=True), fill=TEXT_DARK)
        d.text((90, y + 90), diagnose, font=font(34), fill=TEXT_GREY)
        # status pill
        pill_w = 280
        d.rounded_rectangle((90, y + 150, 90 + pill_w, y + 200), radius=25, fill=color)
        d.text((110, y + 158), status.upper(), font=font(28, bold=True), fill=WHITE)
        d.text((PHONE_W - 280, y + 158), wait, font=font(34, bold=True), fill=TEXT_DARK)
        y += 260
    out = os.path.join(OUT, "screenshot_2_warteliste.png")
    img.save(out, "PNG")
    print("wrote", out)

def screenshot_neuer_patient():
    img, d = base_phone("Neuer Patient")
    fields = [
        ("Name *", "Schmidt"),
        ("Vorname *", "Maria"),
        ("Telefon *", "0721 123456"),
        ("Adresse", "Karlsruhe, Kaiserstr. 12"),
        ("Störungsbild", "Dysphagie"),
        ("Versicherung", "KK"),
        ("Termin-Wunsch", "nachmittags"),
    ]
    y = 280
    for label, value in fields:
        d.text((60, y), label, font=font(30), fill=TEXT_GREY)
        card(d, 50, y + 50, PHONE_W - 100, 110)
        d.text((80, y + 80), value, font=font(40), fill=TEXT_DARK)
        y += 200
    # Button
    by = y + 30
    d.rounded_rectangle((50, by, PHONE_W - 50, by + 130), radius=20, fill=TEAL)
    bbox = d.textbbox((0, 0), "Patient speichern", font=font(44, bold=True))
    bw = bbox[2] - bbox[0]
    d.text(((PHONE_W - bw) // 2, by + 38), "Patient speichern", font=font(44, bold=True), fill=WHITE)
    out = os.path.join(OUT, "screenshot_3_neuer_patient.png")
    img.save(out, "PNG")
    print("wrote", out)

def screenshot_statistik():
    img, d = base_phone("Statistiken")
    # KPI strip
    d.text((60, 280), "Durchschnittliche Wartezeit", font=font(34), fill=TEXT_GREY)
    d.text((60, 330), "23 Tage", font=font(110, bold=True), fill=TEAL)

    # Chart card
    chx, chy = 50, 520
    chw, chh = PHONE_W - 100, 600
    card(d, chx, chy, chw, chh)
    d.text((chx + 40, chy + 30), "Störungsbild-Verteilung", font=font(36, bold=True), fill=TEXT_DARK)
    # Pie chart
    cx, cy, r = chx + chw // 2, chy + 350, 180
    segments = [(0, 120, ORANGE), (120, 220, TEAL), (220, 290, BLUE), (290, 360, GREEN)]
    for s, e, c in segments:
        d.pieslice((cx - r, cy - r, cx + r, cy + r), s, e, fill=c)
    # Legend
    legends = [("Dysphagie 33%", ORANGE), ("Stottern 28%", TEAL), ("Aphasie 19%", BLUE), ("Sprachentw. 20%", GREEN)]
    ly = chy + chh + 30
    for i, (label, color) in enumerate(legends):
        lx = 70 + (i % 2) * 480
        ly2 = ly + (i // 2) * 60
        d.rounded_rectangle((lx, ly2 + 8, lx + 30, ly2 + 38), radius=4, fill=color)
        d.text((lx + 50, ly2), label, font=font(32), fill=TEXT_DARK)
    out = os.path.join(OUT, "screenshot_4_statistik.png")
    img.save(out, "PNG")
    print("wrote", out)

if __name__ == "__main__":
    make_feature()
    screenshot_dashboard()
    screenshot_warteliste()
    screenshot_neuer_patient()
    screenshot_statistik()
    print("\nAll assets written to:", OUT)
