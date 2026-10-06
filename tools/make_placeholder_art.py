#!/usr/bin/env python3
"""仮の絵（子供が描いたようなヘタウマ風のSVG）を作る。

使い方:  python3 tools/make_placeholder_art.py
出力:    assets/illustrations/sketches/*.svg, assets/illustrations/portraits/*.svg

本物の絵ができたら、同じ名前で .png を置けばそちらが優先される（ゲーム側は png → webp → jpg → svg の順に探す）。
"""
import math
import os
import random

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "illustrations")
INK = "#3b2a1e"
W, H = 400, 300


class Pen:
    """ガタガタした線と、はみ出した色ぬりで描く。"""

    def __init__(self, seed, width, height):
        self.rng = random.Random(seed)
        self.w, self.h = width, height
        self.items = []

    def j(self, amp):
        return self.rng.uniform(-amp, amp)

    def wob(self, pts, amp=3.0, closed=False):
        """各点を少しずらし、線分の途中にも揺れを足す。"""
        out = []
        n = len(pts)
        rng = n if closed else n - 1
        for i in range(rng):
            (x0, y0), (x1, y1) = pts[i], pts[(i + 1) % n]
            out.append((x0 + self.j(amp), y0 + self.j(amp)))
            segs = max(1, int(math.hypot(x1 - x0, y1 - y0) // 28))
            for s in range(1, segs):
                t = s / segs
                out.append((x0 + (x1 - x0) * t + self.j(amp * 0.8), y0 + (y1 - y0) * t + self.j(amp * 0.8)))
        if not closed:
            out.append((pts[-1][0] + self.j(amp), pts[-1][1] + self.j(amp)))
        return out

    @staticmethod
    def d(pts, closed=False):
        s = "M " + " L ".join("%.1f %.1f" % p for p in pts)
        return s + (" Z" if closed else "")

    def shape(self, pts, fill=None, stroke=INK, width=5, amp=3.0, closed=True):
        pts = self.wob(pts, amp, closed)
        if fill:  # わざと少しずれた色ぬり
            off = [(x + self.j(5) + 3, y + self.j(5) + 3) for x, y in pts]
            self.items.append('<path d="%s" fill="%s" stroke="none"/>' % (self.d(off, True), fill))
        if stroke:
            self.items.append('<path d="%s" fill="none" stroke="%s" stroke-width="%d" stroke-linecap="round" stroke-linejoin="round"/>' % (self.d(pts, closed), stroke, width))

    def line(self, a, b, width=5, color=INK, amp=2.5):
        pts = self.wob([a, b], amp)
        self.items.append('<path d="%s" fill="none" stroke="%s" stroke-width="%d" stroke-linecap="round" stroke-linejoin="round"/>' % (self.d(pts), color, width))

    def polyline(self, pts, width=5, color=INK, amp=2.0):
        self.items.append('<path d="%s" fill="none" stroke="%s" stroke-width="%d" stroke-linecap="round" stroke-linejoin="round"/>' % (self.d(self.wob(pts, amp)), color, width))

    def blob(self, cx, cy, rx, ry, fill=None, n=14, amp=3.0, width=5, stroke=INK):
        pts = [(cx + rx * math.cos(2 * math.pi * i / n), cy + ry * math.sin(2 * math.pi * i / n)) for i in range(n)]
        self.shape(pts, fill, stroke, width, amp, True)

    def dot(self, x, y, r=4, color=INK):
        self.items.append('<circle cx="%.1f" cy="%.1f" r="%.1f" fill="%s"/>' % (x + self.j(1), y + self.j(1), r, color))

    def svg(self):
        return ('<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d">\n%s\n</svg>\n'
                % (self.w, self.h, self.w, self.h, "\n".join(self.items)))


def ground(p, y=250):
    p.polyline([(40, y), (140, y + 4), (250, y - 3), (360, y + 2)], 4, "#7a6a55")


def mushroom():
    p = Pen(1, W, H)
    ground(p)
    p.shape([(175, 250), (170, 170), (225, 168), (222, 250)], "#f3e6c4")             # 軸
    p.shape([(95, 175), (110, 110), (200, 70), (290, 110), (305, 175), (200, 160)], "#4a7ad8")  # かさ
    for x, y, r in [(150, 125, 11), (205, 105, 13), (255, 135, 10), (185, 150, 8)]:  # 青い斑点
        p.blob(x, y, r, r, "#b9d3ff", 8, 1.5, 3)
    p.polyline([(95, 250), (100, 232), (108, 250)], 4, "#3f8d4a")                      # 草
    p.polyline([(290, 250), (298, 228), (306, 250)], 4, "#3f8d4a")
    return p


def beast():
    p = Pen(2, W, H)
    ground(p)
    p.blob(185, 170, 95, 55, "#a56a3a", 14, 4)                                          # 体
    p.shape([(95, 170), (80, 110), (110, 120), (135, 105), (145, 140), (140, 190)], "#a56a3a")  # 頭
    p.shape([(88, 118), (80, 90), (102, 108)], "#a56a3a")                                # 耳
    p.shape([(122, 108), (132, 80), (140, 112)], "#a56a3a")
    p.dot(103, 138, 4); p.dot(124, 134, 4)                                                # 目
    p.line((95, 126), (110, 132), 4); p.line((130, 126), (118, 132), 4)                  # おこりまゆ
    for x in (140, 175, 220, 255):                                                       # 足
        p.shape([(x, 205), (x - 6, 245), (x + 14, 245), (x + 14, 205)], "#8a5528", amp=2)
    for k in range(3):                                                                    # 長いつめ
        p.line((78 + k * 9, 245), (66 + k * 9, 268), 4, "#f1efe6")
    p.polyline([(275, 160), (310, 130), (330, 95)], 7, "#a56a3a")                          # しっぽ
    return p


def statue():
    p = Pen(3, W, H)
    ground(p)
    p.shape([(120, 250), (122, 215), (278, 215), (280, 250)], "#b9b4a8")                 # だいざ
    p.shape([(150, 215), (155, 130), (245, 130), (250, 215)], "#c9c4b8")                 # からだ
    p.blob(200, 95, 38, 40, "#c9c4b8", 12, 3)                                            # あたま
    for x in (186, 214):                                                                  # 光る目
        p.blob(x, 92, 7, 7, "#ffd93b", 8, 1, 3)
    for dx, dy in [(-24, -10), (24, -10), (-20, 14), (20, 14)]:
        p.line((200 + dx * 0.6 + (-14 if dx < 0 else 14), 92 + dy * 0.2), (200 + dx * 1.7, 92 + dy * 1.4), 3, "#ffd93b")
    p.line((160, 150), (130, 190), 6); p.line((240, 150), (270, 190), 6)                 # うで
    return p


def moss():
    p = Pen(4, W, H)
    ground(p)
    for cx, cy, rx, ry in [(120, 215, 55, 35), (210, 200, 60, 45), (300, 218, 50, 32)]:
        p.blob(cx, cy, rx, ry, "#4cae5c", 12, 4)
    for x, y in [(110, 205), (150, 225), (200, 185), (235, 215), (290, 210), (315, 228), (175, 215)]:
        p.blob(x, y, 5, 5, "#fff27a", 6, 1, 2)                                            # 光るつぶ
        p.line((x - 9, y), (x + 9, y), 2, "#e0b800"); p.line((x, y - 9), (x, y + 9), 2, "#e0b800")
    return p


def pit():
    p = Pen(5, W, H)
    p.shape([(40, 80), (360, 80), (385, 270), (15, 270)], "#d9cfb6")                    # 床
    p.line((120, 80), (95, 270), 3, "#7a6a55"); p.line((200, 80), (200, 270), 3, "#7a6a55"); p.line((280, 80), (305, 270), 3, "#7a6a55")
    p.line((70, 150), (330, 150), 3, "#7a6a55"); p.line((50, 215), (350, 215), 3, "#7a6a55")
    p.shape([(205, 155), (275, 155), (292, 213), (203, 213)], "#7b6a57")               # 色の濃い床
    p.blob(240, 185, 22, 12, "#2b2118", 10, 2, 3)                                        # 穴
    return p


def pit_deep():
    p = Pen(6, W, H)
    p.shape([(40, 60), (360, 60), (375, 110), (25, 110)], "#d9cfb6")                    # 床のふち
    p.blob(200, 110, 105, 30, "#2b2118", 16, 3)                                          # 大きな穴
    for k, c in enumerate(["#4a3a2c", "#3a2c20", "#2b2118"]):
        p.blob(200, 135 + k * 38, 80 - k * 20, 22, c, 12, 3, 3, None)
    p.polyline([(200, 125), (203, 170), (198, 215), (202, 262)], 3, "#f1efe6", 2)       # 落ちていく石のあと
    p.blob(200, 80, 9, 8, "#8a8578", 7, 1, 3)                                            # 石
    p.line((330, 200), (330, 245), 4); p.polyline([(318, 215), (330, 195), (342, 215)], 4)  # 「？」っぽいしるし
    p.dot(330, 262, 4)
    return p


def bat():
    p = Pen(7, W, H)
    p.polyline([(20, 40), (100, 46), (200, 38), (300, 46), (385, 40)], 6, "#7a6a55")    # 天井
    for cx, base in [(95, 90), (200, 105), (305, 90)]:
        p.line((cx, 44), (cx, base), 3, "#7a6a55")
        p.shape([(cx - 20, base + 20), (cx - 70, base + 5), (cx - 50, base + 45), (cx - 28, base + 38)], "#5b4a78")   # 左はね
        p.shape([(cx + 20, base + 20), (cx + 70, base + 5), (cx + 50, base + 45), (cx + 28, base + 38)], "#5b4a78")   # 右はね
        p.blob(cx, base + 28, 24, 30, "#6b5890", 10, 3)
        p.shape([(cx - 16, base + 6), (cx - 20, base - 14), (cx - 4, base + 2)], "#6b5890", amp=1.5)
        p.shape([(cx + 16, base + 6), (cx + 20, base - 14), (cx + 4, base + 2)], "#6b5890", amp=1.5)
        p.dot(cx - 8, base + 24, 3, "#ffffff"); p.dot(cx + 8, base + 24, 3, "#ffffff")
    return p


def pattern():
    p = Pen(8, W, H)
    p.shape([(40, 40), (360, 40), (360, 165), (40, 165)], "#cfc7b4")                    # かべ
    for y in (75, 110, 145):
        p.polyline([(60, y), (90, y - 22), (120, y), (150, y - 22), (180, y), (210, y - 22), (240, y), (270, y - 22), (300, y), (330, y - 22)], 4, "#7b4a2a")
    p.shape([(100, 190), (300, 190), (320, 270), (80, 270)], "#bfb8a6")                  # ゆかの石
    p.polyline([(125, 245), (155, 215), (185, 245), (215, 215), (245, 245), (275, 215)], 4, "#7b4a2a")
    return p


def tablet():
    p = Pen(9, W, H)
    ground(p)
    p.shape([(110, 250), (112, 90), (250, 80), (254, 248)], "#b9b4a8")                   # 石板
    for y in (115, 145, 175, 205):
        p.polyline([(135, y), (150, y - 10), (165, y), (180, y - 10), (195, y), (210, y - 10), (225, y)], 3, "#7b6a57", 1.5)
    p.blob(310, 215, 22, 26, "#ffd35e", 10, 2)                                           # ランプ
    p.line((300, 190), (300, 170), 4); p.line((320, 190), (320, 170), 4); p.line((296, 170), (324, 170), 4)
    for dx, dy in [(-40, -10), (40, -10), (0, -45), (-30, 30), (30, 30)]:               # 光
        p.line((310 + dx * 0.55, 215 + dy * 0.55), (310 + dx, 215 + dy), 3, "#ffd35e")
    return p


def portrait_childhood():
    p = Pen(11, 256, 256)
    p.shape([(40, 70), (35, 190), (75, 220), (181, 220), (221, 190), (216, 70), (128, 25)], "#8a5a2b")  # かみ（うしろ）
    p.blob(128, 130, 78, 88, "#ffd9b8", 14, 3)                                           # かお
    p.shape([(52, 105), (90, 60), (150, 52), (205, 105), (170, 85), (110, 82)], "#8a5a2b")   # まえがみ
    for x in (100, 158):                                                                  # 目
        p.blob(x, 135, 8, 11, "#2b2118", 8, 1, 2)
    p.dot(103, 131, 2.5, "#ffffff"); p.dot(161, 131, 2.5, "#ffffff")
    p.blob(78, 160, 14, 8, "#ffb3a6", 8, 1, 1, None); p.blob(178, 160, 14, 8, "#ffb3a6", 8, 1, 1, None)  # ほっぺ
    p.polyline([(105, 175), (128, 190), (152, 175)], 4, "#c0392b")                       # わらい
    return p


def portrait_mercenary():
    p = Pen(12, 256, 256)
    p.blob(128, 135, 76, 86, "#e9bd94", 14, 3)                                           # かお
    p.shape([(52, 108), (60, 60), (128, 38), (196, 60), (204, 108), (176, 88), (80, 88)], "#4b4b55")   # かみ・はちまき
    p.shape([(54, 100), (202, 100), (202, 118), (54, 118)], "#8f2b2b", amp=2)
    p.line((96, 140), (118, 146), 5); p.line((160, 140), (138, 146), 5)                  # するどい目
    p.dot(108, 152, 4); p.dot(148, 152, 4)
    p.line((150, 118), (186, 182), 4, "#9a4a3a", 3)                                       # きずあと
    p.polyline([(108, 195), (128, 188), (150, 196)], 4, "#6b3a2a")                       # への字ぐち
    return p


SKETCHES = {
    "mushroom": mushroom, "beast": beast, "statue": statue, "moss": moss, "pit": pit,
    "pit_deep": pit_deep, "bat": bat, "pattern": pattern, "tablet": tablet,
}
PORTRAITS = {"childhood": portrait_childhood, "mercenary": portrait_mercenary}


def main():
    for folder, table in (("sketches", SKETCHES), ("portraits", PORTRAITS)):
        os.makedirs(os.path.join(OUT, folder), exist_ok=True)
        for name, fn in table.items():
            path = os.path.join(OUT, folder, name + ".svg")
            with open(path, "w", encoding="utf-8") as f:
                f.write(fn().svg())
            print("wrote", os.path.relpath(path))


if __name__ == "__main__":
    main()
