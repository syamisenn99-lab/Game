#!/usr/bin/env python3
"""仮の絵（子供が描いたようなヘタウマ風のSVG）を作る。

使い方:  python3 tools/make_placeholder_art.py
出力:    assets/illustrations/sketches/*.svg                … 幼なじみの絵柄（共通の絵）
         assets/illustrations/sketches/<冒険者id>/*.svg    … 冒険者ごとの絵柄（傭兵・医師・貴族）
         assets/illustrations/portraits/*.svg

絵柄:  childhood = 子供が描いたようなヘタウマ / mercenary = 雑で簡素 /
       doctor = きれいな細い線と、矢印・脈拍の書き込み / noble = 細かくて装飾的（額縁や飾り）

本物の絵ができたら、同じ名前で .png を置けばそちらが優先される（ゲーム側は png → webp → jpg → svg の順に探す）。
"""
import math
import os
import random

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "illustrations")
INK = "#3b2a1e"
W, H = 400, 300


# 絵柄ごとの設定: 揺れの大きさ・線の太さ・色ぬり・線の色
STYLES = {
    "childhood": {"amp": 1.0, "width": 1.0, "fill": True, "alpha": 1.0, "ink": INK},
    "mercenary": {"amp": 2.2, "width": 0.8, "fill": False, "alpha": 1.0, "ink": "#4b4b55"},
    "doctor": {"amp": 0.3, "width": 0.55, "fill": True, "alpha": 0.55, "ink": "#2f5d50"},
    "noble": {"amp": 0.15, "width": 0.5, "fill": True, "alpha": 0.5, "ink": "#4a2f5a"},
}


class Pen:
    """ガタガタした線と、はみ出した色ぬりで描く。絵柄（style）で、揺れ・太さ・色ぬりが変わる。"""

    def __init__(self, seed, width, height, style="childhood"):
        self.rng = random.Random(seed)
        self.w, self.h = width, height
        self.style = style
        self.cfg = STYLES[style]
        self.items = []

    def j(self, amp):
        return self.rng.uniform(-amp, amp)

    def wob(self, pts, amp=3.0, closed=False):
        """各点を少しずらし、線分の途中にも揺れを足す。"""
        amp = amp * self.cfg["amp"]
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

    def ink(self, color):
        """線の色。標準の茶色は、絵柄ごとのインク色に置き換える。"""
        return self.cfg["ink"] if color == INK else color

    def sw(self, width):
        return max(1.5, width * self.cfg["width"])

    def shape(self, pts, fill=None, stroke=INK, width=5, amp=3.0, closed=True):
        pts = self.wob(pts, amp, closed)
        if fill and self.cfg["fill"]:  # わざと少しずれた色ぬり
            k = self.cfg["amp"]
            off = [(x + self.j(5 * k) + 3 * k, y + self.j(5 * k) + 3 * k) for x, y in pts]
            self.items.append('<path d="%s" fill="%s" fill-opacity="%.2f" stroke="none"/>' % (self.d(off, True), fill, self.cfg["alpha"]))
        if stroke:
            self.items.append('<path d="%s" fill="none" stroke="%s" stroke-width="%.1f" stroke-linecap="round" stroke-linejoin="round"/>' % (self.d(pts, closed), self.ink(stroke), self.sw(width)))

    def line(self, a, b, width=5, color=INK, amp=2.5):
        pts = self.wob([a, b], amp)
        self.items.append('<path d="%s" fill="none" stroke="%s" stroke-width="%.1f" stroke-linecap="round" stroke-linejoin="round"/>' % (self.d(pts), self.ink(color), self.sw(width)))

    def polyline(self, pts, width=5, color=INK, amp=2.0):
        self.items.append('<path d="%s" fill="none" stroke="%s" stroke-width="%.1f" stroke-linecap="round" stroke-linejoin="round"/>' % (self.d(self.wob(pts, amp)), self.ink(color), self.sw(width)))

    def blob(self, cx, cy, rx, ry, fill=None, n=14, amp=3.0, width=5, stroke=INK):
        pts = [(cx + rx * math.cos(2 * math.pi * i / n), cy + ry * math.sin(2 * math.pi * i / n)) for i in range(n)]
        self.shape(pts, fill, stroke, width, amp, True)

    def dot(self, x, y, r=4, color=INK):
        k = self.cfg["amp"]
        self.items.append('<circle cx="%.1f" cy="%.1f" r="%.1f" fill="%s"/>' % (x + self.j(1 * k), y + self.j(1 * k), r * (0.8 if self.cfg["width"] < 1 else 1), self.ink(color)))

    # ---- 絵柄ごとの書き込み（仕上げ）
    def arrow(self, a, b, color):
        ang = math.atan2(b[1] - a[1], b[0] - a[0])
        self.items.append('<path d="M %.1f %.1f L %.1f %.1f" stroke="%s" stroke-width="1.5" fill="none" stroke-linecap="round"/>' % (a[0], a[1], b[0], b[1], color))
        for da in (2.7, -2.7):
            self.items.append('<path d="M %.1f %.1f L %.1f %.1f" stroke="%s" stroke-width="1.5" fill="none" stroke-linecap="round"/>' % (
                b[0], b[1], b[0] + 9 * math.cos(ang + da), b[1] + 9 * math.sin(ang + da), color))

    def finish(self):
        if self.style == "doctor":
            c = "#c0392b"
            # 脈拍の線（左上）
            hb = [(14, 22), (50, 22), (58, 8), (68, 38), (78, 22), (130, 22)]
            self.items.append('<path d="%s" fill="none" stroke="%s" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>' % (self.d(hb), c))
            # 観察点をしめす矢印と、点線の円
            for (ax, ay), (bx, by) in [((self.w - 30, 28), (self.w * 0.62, self.h * 0.42)), ((30, self.h - 24), (self.w * 0.34, self.h * 0.62))]:
                self.arrow((ax, ay), (bx, by), c)
                self.items.append('<circle cx="%.1f" cy="%.1f" r="16" fill="none" stroke="%s" stroke-width="1.2" stroke-dasharray="3 3"/>' % (bx, by, c))
            self.items.append('<path d="M 14 %d L %d %d" stroke="%s" stroke-width="1" stroke-dasharray="2 4"/>' % (self.h - 10, self.w - 14, self.h - 10, c))
        elif self.style == "noble":
            c = "#8a6a2a"
            m = 8
            for inset, wd in ((m, 2.0), (m + 6, 0.8)):  # 二重の額縁
                self.items.append('<rect x="%d" y="%d" width="%d" height="%d" fill="none" stroke="%s" stroke-width="%.1f"/>' % (inset, inset, self.w - 2 * inset, self.h - 2 * inset, c, wd))
            for cx, cy in ((m + 3, m + 3), (self.w - m - 3, m + 3), (m + 3, self.h - m - 3), (self.w - m - 3, self.h - m - 3)):  # 角の飾り
                self.items.append('<circle cx="%d" cy="%d" r="7" fill="none" stroke="%s" stroke-width="1"/>' % (cx, cy, c))
                self.items.append('<circle cx="%d" cy="%d" r="2.5" fill="%s"/>' % (cx, cy, c))
            for i in range(14, self.w - 14, 14):  # 下の寸法線の目盛り
                self.items.append('<path d="M %d %d L %d %d" stroke="%s" stroke-width="0.8"/>' % (i, self.h - 24, i, self.h - 18 - (4 if i % 56 == 0 else 0), c))
            self.items.append('<path d="M 14 %d L %d %d" stroke="%s" stroke-width="0.8"/>' % (self.h - 24, self.w - 14, self.h - 24, c))
            for k in range(9):  # 左上のハッチング
                self.items.append('<path d="M %d 20 L 20 %d" stroke="%s" stroke-width="0.6"/>' % (20 + k * 9, 20 + k * 9, c))

    def svg(self):
        self.finish()
        return ('<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d">\n%s\n</svg>\n'
                % (self.w, self.h, self.w, self.h, "\n".join(self.items)))


def ground(p, y=250):
    p.polyline([(40, y), (140, y + 4), (250, y - 3), (360, y + 2)], 4, "#7a6a55")


def mushroom(style="childhood"):
    p = Pen(1, W, H, style)
    ground(p)
    p.shape([(175, 250), (170, 170), (225, 168), (222, 250)], "#f3e6c4")             # 軸
    p.shape([(95, 175), (110, 110), (200, 70), (290, 110), (305, 175), (200, 160)], "#4a7ad8")  # かさ
    for x, y, r in [(150, 125, 11), (205, 105, 13), (255, 135, 10), (185, 150, 8)]:  # 青い斑点
        p.blob(x, y, r, r, "#b9d3ff", 8, 1.5, 3)
    p.polyline([(95, 250), (100, 232), (108, 250)], 4, "#3f8d4a")                      # 草
    p.polyline([(290, 250), (298, 228), (306, 250)], 4, "#3f8d4a")
    return p


def beast(style="childhood"):
    p = Pen(2, W, H, style)
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


def statue(style="childhood"):
    p = Pen(3, W, H, style)
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


def moss(style="childhood"):
    p = Pen(4, W, H, style)
    ground(p)
    for cx, cy, rx, ry in [(120, 215, 55, 35), (210, 200, 60, 45), (300, 218, 50, 32)]:
        p.blob(cx, cy, rx, ry, "#4cae5c", 12, 4)
    for x, y in [(110, 205), (150, 225), (200, 185), (235, 215), (290, 210), (315, 228), (175, 215)]:
        p.blob(x, y, 5, 5, "#fff27a", 6, 1, 2)                                            # 光るつぶ
        p.line((x - 9, y), (x + 9, y), 2, "#e0b800"); p.line((x, y - 9), (x, y + 9), 2, "#e0b800")
    return p


def pit(style="childhood"):
    p = Pen(5, W, H, style)
    p.shape([(40, 80), (360, 80), (385, 270), (15, 270)], "#d9cfb6")                    # 床
    p.line((120, 80), (95, 270), 3, "#7a6a55"); p.line((200, 80), (200, 270), 3, "#7a6a55"); p.line((280, 80), (305, 270), 3, "#7a6a55")
    p.line((70, 150), (330, 150), 3, "#7a6a55"); p.line((50, 215), (350, 215), 3, "#7a6a55")
    p.shape([(205, 155), (275, 155), (292, 213), (203, 213)], "#7b6a57")               # 色の濃い床
    p.blob(240, 185, 22, 12, "#2b2118", 10, 2, 3)                                        # 穴
    return p


def pit_deep(style="childhood"):
    p = Pen(6, W, H, style)
    p.shape([(40, 60), (360, 60), (375, 110), (25, 110)], "#d9cfb6")                    # 床のふち
    p.blob(200, 110, 105, 30, "#2b2118", 16, 3)                                          # 大きな穴
    for k, c in enumerate(["#4a3a2c", "#3a2c20", "#2b2118"]):
        p.blob(200, 135 + k * 38, 80 - k * 20, 22, c, 12, 3, 3, None)
    p.polyline([(200, 125), (203, 170), (198, 215), (202, 262)], 3, "#f1efe6", 2)       # 落ちていく石のあと
    p.blob(200, 80, 9, 8, "#8a8578", 7, 1, 3)                                            # 石
    p.line((330, 200), (330, 245), 4); p.polyline([(318, 215), (330, 195), (342, 215)], 4)  # 「？」っぽいしるし
    p.dot(330, 262, 4)
    return p


def bat(style="childhood"):
    p = Pen(7, W, H, style)
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


def pattern(style="childhood"):
    p = Pen(8, W, H, style)
    p.shape([(40, 40), (360, 40), (360, 165), (40, 165)], "#cfc7b4")                    # かべ
    for y in (75, 110, 145):
        p.polyline([(60, y), (90, y - 22), (120, y), (150, y - 22), (180, y), (210, y - 22), (240, y), (270, y - 22), (300, y), (330, y - 22)], 4, "#7b4a2a")
    p.shape([(100, 190), (300, 190), (320, 270), (80, 270)], "#bfb8a6")                  # ゆかの石
    p.polyline([(125, 245), (155, 215), (185, 245), (215, 215), (245, 245), (275, 215)], 4, "#7b4a2a")
    return p


def tablet(style="childhood"):
    p = Pen(9, W, H, style)
    ground(p)
    p.shape([(110, 250), (112, 90), (250, 80), (254, 248)], "#b9b4a8")                   # 石板
    for y in (115, 145, 175, 205):
        p.polyline([(135, y), (150, y - 10), (165, y), (180, y - 10), (195, y), (210, y - 10), (225, y)], 3, "#7b6a57", 1.5)
    p.blob(310, 215, 22, 26, "#ffd35e", 10, 2)                                           # ランプ
    p.line((300, 190), (300, 170), 4); p.line((320, 190), (320, 170), 4); p.line((296, 170), (324, 170), 4)
    for dx, dy in [(-40, -10), (40, -10), (0, -45), (-30, 30), (30, 30)]:               # 光
        p.line((310 + dx * 0.55, 215 + dy * 0.55), (310 + dx, 215 + dy), 3, "#ffd35e")
    return p


def portrait_childhood(style="childhood"):
    p = Pen(11, 256, 256, style)
    p.shape([(40, 70), (35, 190), (75, 220), (181, 220), (221, 190), (216, 70), (128, 25)], "#8a5a2b")  # かみ（うしろ）
    p.blob(128, 130, 78, 88, "#ffd9b8", 14, 3)                                           # かお
    p.shape([(52, 105), (90, 60), (150, 52), (205, 105), (170, 85), (110, 82)], "#8a5a2b")   # まえがみ
    for x in (100, 158):                                                                  # 目
        p.blob(x, 135, 8, 11, "#2b2118", 8, 1, 2)
    p.dot(103, 131, 2.5, "#ffffff"); p.dot(161, 131, 2.5, "#ffffff")
    p.blob(78, 160, 14, 8, "#ffb3a6", 8, 1, 1, None); p.blob(178, 160, 14, 8, "#ffb3a6", 8, 1, 1, None)  # ほっぺ
    p.polyline([(105, 175), (128, 190), (152, 175)], 4, "#c0392b")                       # わらい
    return p


def portrait_mercenary(style="childhood"):
    p = Pen(12, 256, 256, style)
    p.blob(128, 135, 76, 86, "#e9bd94", 14, 3)                                           # かお
    p.shape([(52, 108), (60, 60), (128, 38), (196, 60), (204, 108), (176, 88), (80, 88)], "#4b4b55")   # かみ・はちまき
    p.shape([(54, 100), (202, 100), (202, 118), (54, 118)], "#8f2b2b", amp=2)
    p.line((96, 140), (118, 146), 5); p.line((160, 140), (138, 146), 5)                  # するどい目
    p.dot(108, 152, 4); p.dot(148, 152, 4)
    p.line((150, 118), (186, 182), 4, "#9a4a3a", 3)                                       # きずあと
    p.polyline([(108, 195), (128, 188), (150, 196)], 4, "#6b3a2a")                       # への字ぐち
    return p


def herb(style="childhood"):
    p = Pen(13, W, H, style)
    ground(p)
    p.line((200, 250), (200, 150), 5, "#3f8d4a")                                         # くき
    for (x0, y0, x1, y1, x2, y2) in [(200, 200, 135, 180, 120, 215), (200, 180, 265, 160, 285, 195), (200, 150, 160, 105, 200, 90), (200, 150, 245, 110, 205, 92)]:
        p.shape([(x0, y0), (x1, y1), (x2, y2)], "#8fd1a0", amp=2)                         # 葉
        p.line((x0, y0), ((x1 + x2) / 2, (y1 + y2) / 2), 3, "#c9d6dd", 1.5)              # 銀色の葉脈
    p.blob(200, 80, 14, 14, "#e8e4ff", 8, 1.5, 3)                                          # つぼみ
    for dx, dy in [(-26, -10), (26, -10), (0, -30)]:
        p.line((200 + dx * 0.6, 80 + dy * 0.6), (200 + dx, 80 + dy), 2, "#9aa7ff")
    p.polyline([(95, 250), (100, 232), (108, 250)], 4, "#3f8d4a")
    return p


def keyhole(style="childhood"):
    p = Pen(14, W, H, style)
    p.shape([(95, 262), (95, 70), (200, 28), (305, 70), (305, 262)], "#a99b84")           # 石の扉
    p.line((200, 28), (200, 262), 2, "#7a6a55", 1)                                         # 扉のあわせ目
    pts = []
    for i in range(10):                                                                     # 星形のくぼみ
        r = 44 if i % 2 == 0 else 19
        a = -math.pi / 2 + i * math.pi / 5
        pts.append((200 + r * math.cos(a), 150 + r * math.sin(a)))
    p.shape(pts, "#2b2118", width=4, amp=1.5)
    for y in (82, 214, 240):
        p.line((115, y), (160, y), 3, "#7a6a55", 1.5); p.line((240, y), (285, y), 3, "#7a6a55", 1.5)
    return p


def portrait_doctor(style="childhood"):
    p = Pen(15, 256, 256, style)
    p.shape([(60, 256), (66, 210), (128, 224), (190, 210), (196, 256)], "#f4f7f9")           # 白衣
    p.shape([(100, 214), (128, 250), (156, 214), (140, 206), (128, 228), (116, 206)], "#ffffff", amp=1.5)  # えり
    p.blob(128, 128, 70, 82, "#ffe0c4", 14, 3)                                             # かお
    p.shape([(58, 118), (70, 62), (128, 44), (186, 62), (198, 118), (170, 90), (128, 78), (86, 92)], "#2b3a55")  # かみ
    for x in (100, 156):                                                                    # まるメガネ
        p.blob(x, 128, 21, 21, None, 12, 1.5, 3)
        p.dot(x, 130, 4)
    p.line((121, 128), (135, 128), 3)
    p.line((84, 104), (116, 98), 4); p.line((172, 104), (140, 98), 4)                       # こまりまゆ
    p.blob(128, 176, 11, 13, "#c0392b", 8, 1.5, 3)                                         # あわてた口
    p.polyline([(40, 232), (40, 250), (52, 250)], 3, "#7a6a55")                            # 聴診器
    return p


def portrait_noble(style="childhood"):
    p = Pen(16, 256, 256, style)
    p.shape([(40, 90), (30, 200), (70, 235), (128, 215), (186, 235), (226, 200), (216, 90), (128, 20)], "#e8c44a")  # ながい巻き毛
    p.blob(128, 130, 66, 84, "#fbe3cf", 14, 3)                                             # かお
    p.shape([(60, 238), (80, 250), (100, 236), (120, 252), (140, 236), (160, 252), (180, 236), (196, 250)], "#ffffff", amp=2)  # ひらひらの襟
    p.shape([(66, 100), (90, 58), (128, 52), (166, 58), (190, 100), (160, 82), (128, 76), (96, 82)], "#e8c44a")  # 前髪
    p.dot(100, 126, 4); p.blob(156, 126, 15, 15, None, 12, 1, 3)                            # 片眼鏡
    p.dot(156, 127, 4)
    p.line((171, 138), (200, 190), 2, "#b8942a", 1)                                         # 鎖
    p.line((120, 130), (116, 160), 3); p.line((116, 160), (128, 162), 3)                    # とがった鼻
    p.line((106, 182), (150, 178), 4, "#8a4a3a")                                            # 余裕のある笑み
    p.polyline([(150, 178), (158, 172)], 3, "#8a4a3a")
    p.polyline([(84, 98), (112, 94)], 3); p.polyline([(144, 94), (172, 98)], 3)
    return p


SKETCHES = {
    "mushroom": mushroom, "beast": beast, "statue": statue, "moss": moss, "pit": pit,
    "pit_deep": pit_deep, "bat": bat, "pattern": pattern, "tablet": tablet,
    "herb": herb, "keyhole": keyhole,
}
PORTRAITS = {
    "childhood": portrait_childhood, "mercenary": portrait_mercenary,
    "doctor": portrait_doctor, "noble": portrait_noble,
}
# 冒険者ごとの絵柄で描き直す絵（その冒険者のイベントで使うものだけ）
VARIANTS = {
    "mercenary": ["bat", "beast", "pattern", "statue", "tablet"],
    "doctor": ["mushroom", "herb", "moss", "bat"],
    "noble": ["pattern", "tablet", "statue", "keyhole"],
}


def write(path, content):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        f.write(content)
    print("wrote", os.path.relpath(path))


def main():
    for name, fn in SKETCHES.items():
        write(os.path.join(OUT, "sketches", name + ".svg"), fn().svg())
    for owner, names in VARIANTS.items():
        for name in names:
            write(os.path.join(OUT, "sketches", owner, name + ".svg"), SKETCHES[name](owner).svg())
    for name, fn in PORTRAITS.items():
        write(os.path.join(OUT, "portraits", name + ".svg"), fn().svg())


if __name__ == "__main__":
    main()
