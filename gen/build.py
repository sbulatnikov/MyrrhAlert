"""Сборка ресурсов MyrrhAlert: виджеты, тексты, текстуры.

  python gen/build.py <папка аддона> [папка предпросмотра текстур]
Размеры в макете — в «пикселях макета»; в игре всё умножается на S (как в остальных аддонах, 1.2).
"""
import os, sys, shutil
import numpy as np
sys.path.insert(0, os.path.dirname(__file__))
import tex as T
import xdb as X
from xdb import placement as PL, fmt

S = 1.2


def P(v):
    return int(round(v * S))


_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(_ROOT, 'out', 'MyrrhAlert')
PREV = sys.argv[2] if len(sys.argv) > 2 else os.path.join(_ROOT, 'out', 'preview')
for d in ('Widgets', 'Texts'):
    shutil.rmtree(os.path.join(OUT, d), ignore_errors=True)
shutil.rmtree(PREV, ignore_errors=True)
X.setup(OUT, PREV)

# ------------------------------------------------------------------ палитра (общая с остальными аддонами)
ACC = '#BB1ABD'; ACC_B = '#D045D2'; ACC_I = '#E58BE7'
BG_WIN = '#17141B'; BG_HDR = '#1D1922'; BG_HOVER = '#1F1A24'; BG_IN = '#100E13'
BR_WIN = '#3A2F42'; BR_CTL = '#3A3141'; LINE = '#2A2330'
TXT = '#ECE6EF'; TXT2 = '#BDB4C4'; TXT_OFF = '#8C8393'
WARN = '#FF3B30'            # красный: надпись — предупреждение, а не акцент интерфейса

F_TITLE = ('AllodsFantasy', 18)
F_BODY = ('AllodsSystem', 16)
F_SMALL = ('AllodsSystem', 14)
F_WARN = ('AllodsSystem', 30)

# ------------------------------------------------------------------ текстуры


def box(w, h, r, fill=None, border=None, bw=1.2):
    return T.rrect(T.blank(w, h), 0, 0, w, h, r, fill=fill, border=border, bw=bw)


def fr(name, fill, border=None, size=64, r=7, e=None, bw=1.2):
    return X.frame(name, box(size, size, r, fill, border, bw), e or (r + 3))


def solid(name, color, alpha=1.0):
    img = T.blank(4, 4)
    img[...] = T.hex2rgba(color, alpha)
    return X.stretch(name, img)


def cross(size, color, margin, width):
    """Крестик кнопки «закрыть»: две сглаженные диагонали."""
    ys, xs = np.mgrid[0:size, 0:size].astype(np.float64)
    px, py = xs + 0.5, ys + 0.5
    a, b = margin, size - margin
    # расстояние до диагоналей, обрезанных по квадрату [a, b]
    inside = np.maximum(np.maximum(a - px, px - b), np.maximum(a - py, py - b))
    d = np.minimum(np.abs(px - py), np.abs(px + py - size)) / np.sqrt(2)
    d = np.maximum(d - width / 2, inside)
    img = T.blank(size, size)
    img[...] = T.hex2rgba(color, 0.0)      # цвет прозрачных пикселей = цвет крестика, чтобы края не темнели
    img[..., 3] = T.cov(d)
    return img


TRANSP = X.stretch('Transparent', T.blank(4, 4))
LINE_TEX = solid('Line', LINE)
CURSOR = solid('Cursor', ACC_I)
SELECTION = solid('Selection', ACC, 0.45)
WIN_FRAME = fr('WindowFrame', BG_WIN, BR_WIN, 128, 12, 16)
HDR_FRAME = X.frame('HeaderBack', T.rrect(T.blank(64, 64), 1.2, 1.2, 62.8, 64, (11, 11, 0, 0), fill=BG_HDR), 14)
ACCENT_MARK = X.stretch('AccentMark', box(16, 16, 4, ACC))
FIELD = fr('FieldFrame', BG_IN, BR_CTL, 32, 6, 9)
FIELD_FOCUS = fr('FieldFrameFocus', BG_IN, ACC_I, 32, 6, 9)
BTN_HOVER = fr('IconBtnHover', BG_HOVER, BR_CTL, 32, 6, 9)
APPLY = {'n': fr('ApplyNormal', ACC, ACC_B), 'h': fr('ApplyHover', '#CC3ACE', '#E070E2'), 'p': fr('ApplyPressed', '#9E169F', ACC_B)}
CLOSE_IC = X.stretch('Close', cross(32, TXT2, 8, 3.6))

# ------------------------------------------------------------------ форматы текста


def F(name, f, color, alignx='left', **kw):
    return fmt(name, f[0], f[1], color, alignx, **kw)


def tv(name, x, y, w, h, fref, **kw):
    return X.textview(name, PL(x, y, w, h), fref, **kw)


# ------------------------------------------------------------------ надпись-предупреждение
# по центру сверху, поверх игры; клики сквозь неё проходят
F('Warning', F_WARN, WARN, 'center', literal='НЕДОСТАТОЧНО МИРРЫ', outline=1)
X.textview('Warning', PL(0, 170, 900, 60, 'WIDGET_ALIGN_CENTER'), '../Texts/Warning.txt', visible=False)

# ------------------------------------------------------------------ окно настроек
W_, H_ = 300, 172           # окно (макет)
WW, WH = P(W_), P(H_)
HDR = 40
PAD = 14

# --- шапка: за неё окно перетаскивается
F('TitleText', F_TITLE, TXT, literal='MyrrhAlert')
X.panel('AccentMark', PL(P(12), P(15), 12, 12), back=ACCENT_MARK, transparent=True)
tv('TitleText', P(28), 0, P(200), P(HDR), '../Texts/TitleText.txt')
X.panel('HdrCloseIcon', PL((P(28) - P(16)) // 2, (P(28) - P(16)) // 2, P(16), P(16)), back=CLOSE_IC, transparent=True)
X.button('HdrClose', PL(P(W_ - 34), P(6), P(28), P(28)),
         [{'normal': TRANSP, 'hover': BTN_HOVER, 'pressed': BTN_HOVER, 'reaction': 'ma_close'}],
         children=['HdrCloseIcon.(WidgetPanel).xdb'])
X.panel('Header', PL(0, 0, WW, P(HDR)), back=HDR_FRAME,
        children=['AccentMark.(WidgetPanel).xdb', 'TitleText.(WidgetTextView).xdb', 'HdrClose.(WidgetButton).xdb'])
X.panel('HeaderLine', PL(1, P(HDR) - 1, WW - 2, 1), back=LINE_TEX, transparent=True)

# --- порог: подпись, поле ввода, кнопка
F('ThresholdLabel', F_BODY, TXT, literal='Предупреждать, если мирры меньше')
tv('ThresholdLabel', P(PAD), P(52), P(W_ - 2 * PAD), P(22), '../Texts/ThresholdLabel.txt')

IW, IH = P(120), P(30)
F('ThresholdEdit', F_BODY, TXT)
X.panel('ThresholdFocus', PL(0, 0, IW, IH), back=FIELD_FOCUS, transparent=True, visible=False)
# 7 знаков — это порог до 1 000 000 (MA.THRESHOLD_MAX); фильтр INTEGER пропускает только цифры
X.editline('ThresholdEdit', PL(P(10), 0, IW - P(20), IH), '../Texts/ThresholdEdit.txt', CURSOR, SELECTION, 7,
           'ma_threshold_enter', 'ma_threshold_esc', focus='ma_threshold_focus', filter_alias='INTEGER')
X.panel('ThresholdBox', PL(P(PAD), P(80), IW, IH), back=FIELD,
        children=['ThresholdFocus.(WidgetPanel).xdb', 'ThresholdEdit.(WidgetEditLine).xdb'])

F('ApplyBtn', F_BODY, '#FFFFFF', 'center', tag='button_label')
X.button('Apply', PL(P(PAD + 120 + 10), P(80), P(W_ - 2 * PAD - 130), IH),
         [{'normal': APPLY['n'], 'hover': APPLY['h'], 'pressed': APPLY['p'], 'text': X.text_file('Apply', 'Применить'),
           'fmt': '../Texts/ApplyBtn.txt', 'reaction': 'ma_apply'}])

# --- сколько мирры сейчас и подсказка про ноль
F('AmountText', F_BODY, TXT2)
tv('AmountText', P(PAD), P(120), P(W_ - 2 * PAD), P(20), '../Texts/AmountText.txt')
F('HintText', F_SMALL, TXT_OFF, literal='0 — предупреждение выключено')
tv('HintText', P(PAD), P(142), P(W_ - 2 * PAD), P(18), '../Texts/HintText.txt')

X.panel('MAWindow', PL(440, 240, WW, WH), back=WIN_FRAME,
        children=['Header.(WidgetPanel).xdb', 'HeaderLine.(WidgetPanel).xdb', 'ThresholdLabel.(WidgetTextView).xdb',
                  'ThresholdBox.(WidgetPanel).xdb', 'Apply.(WidgetButton).xdb', 'AmountText.(WidgetTextView).xdb',
                  'HintText.(WidgetTextView).xdb'], visible=False, priority=900)

X.form('MainForm', ['Warning.(WidgetTextView).xdb', 'MAWindow.(WidgetPanel).xdb'])
