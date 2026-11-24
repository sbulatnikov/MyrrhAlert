"""Растеризация простых фигур и запись текстур в формате Allods (DXT5 + zlib)."""
import os, struct, subprocess, tempfile, zlib
import numpy as np
from PIL import Image


def hex2rgba(c, a=1.0):
    c = c.lstrip('#')
    r, g, b = int(c[0:2], 16), int(c[2:4], 16), int(c[4:6], 16)
    if len(c) == 8:
        a = int(c[6:8], 16) / 255.0
    return np.array([r / 255.0, g / 255.0, b / 255.0, a], dtype=np.float64)


def blank(w, h):
    return np.zeros((h, w, 4), dtype=np.float64)


def over(dst, color, cov):
    """Наложение цвета с покрытием cov (0..1) поверх dst, прямая альфа."""
    sa = color[3] * cov
    da = dst[..., 3]
    oa = sa + da * (1 - sa)
    for i in range(3):
        num = color[i] * sa + dst[..., i] * da * (1 - sa)
        dst[..., i] = np.where(oa > 1e-6, num / np.maximum(oa, 1e-6), color[i])
    dst[..., 3] = oa
    return dst


def sdf_rrect(w, h, x0, y0, x1, y1, radii):
    """Знаковое расстояние до скруглённого прямоугольника (radii: tl, tr, br, bl)."""
    ys, xs = np.mgrid[0:h, 0:w].astype(np.float64)
    px, py = xs + 0.5, ys + 0.5
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    hx, hy = (x1 - x0) / 2, (y1 - y0) / 2
    tl, tr, br, bl = radii
    r = np.where(px < cx, np.where(py < cy, tl, bl), np.where(py < cy, tr, br))
    qx = np.abs(px - cx) - hx + r
    qy = np.abs(py - cy) - hy + r
    outside = np.sqrt(np.maximum(qx, 0) ** 2 + np.maximum(qy, 0) ** 2)
    inside = np.minimum(np.maximum(qx, qy), 0)
    return outside + inside - r


def cov(d):
    return np.clip(0.5 - d, 0.0, 1.0)


def rrect(img, x0, y0, x1, y1, r, fill=None, border=None, bw=1.0):
    h, w = img.shape[:2]
    radii = r if isinstance(r, (tuple, list)) else (r, r, r, r)
    d = sdf_rrect(w, h, x0, y0, x1, y1, radii)
    if border is not None:
        over(img, hex2rgba(border) if isinstance(border, str) else border, cov(d))
        if fill is not None:
            inner = tuple(max(0.0, q - bw) for q in radii)
            di = sdf_rrect(w, h, x0 + bw, y0 + bw, x1 - bw, y1 - bw, inner)
            # заливка заменяет внутреннюю часть рамки
            c = cov(di)
            col = hex2rgba(fill) if isinstance(fill, str) else fill
            for i in range(4):
                img[..., i] = img[..., i] * (1 - c) + col[i] * c if i < 3 else img[..., 3] * (1 - c) + col[3] * c
    elif fill is not None:
        over(img, hex2rgba(fill) if isinstance(fill, str) else fill, cov(d))
    return img


def ring(img, x0, y0, x1, y1, r, color, bw):
    h, w = img.shape[:2]
    d = sdf_rrect(w, h, x0, y0, x1, y1, (r, r, r, r))
    c = np.clip(0.5 - np.abs(d + bw / 2) + bw / 2, 0, 1)
    over(img, hex2rgba(color) if isinstance(color, str) else color, c)
    return img


def svg_icon(paths, color, size, stroke=1.6, view=16, fill=False):
    """Иконка из SVG-путей (координаты 0..view), растеризуется rsvg-convert."""
    body = ''.join(
        '<path d="%s" fill="%s" stroke="%s" stroke-width="%s" stroke-linecap="round" stroke-linejoin="round"/>'
        % (d, color if fill else 'none', 'none' if fill else color, stroke) for d in paths)
    svg = ('<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %s %s">%s</svg>'
           % (size, size, view, view, body))
    with tempfile.TemporaryDirectory() as td:
        sp, pp = os.path.join(td, 'i.svg'), os.path.join(td, 'i.png')
        open(sp, 'w').write(svg)
        subprocess.check_call(['rsvg-convert', '-w', str(size), '-h', str(size), sp, '-o', pp])
        im = np.asarray(Image.open(pp).convert('RGBA')).astype(np.float64) / 255.0
    # цвет прозрачных пикселей = цвет иконки (для DXT, чтобы края не темнели)
    col = hex2rgba(color)
    a = im[..., 3:4]
    rgb = np.where(a > 0.001, im[..., :3], col[:3])
    return np.concatenate([rgb, a], axis=2)


def paste(dst, src, x, y):
    h, w = src.shape[:2]
    region = dst[y:y + h, x:x + w]
    a = src[..., 3]
    for i in range(3):
        pass
    over_region = region.copy()
    sa = a
    da = over_region[..., 3]
    oa = sa + da * (1 - sa)
    for i in range(3):
        num = src[..., i] * sa + over_region[..., i] * da * (1 - sa)
        over_region[..., i] = np.where(oa > 1e-6, num / np.maximum(oa, 1e-6), src[..., i])
    over_region[..., 3] = oa
    dst[y:y + h, x:x + w] = over_region
    return dst


# ---------------------------------------------------------------- DXT5

def _c565(c):
    r, g, b = (np.clip(np.round(c * [31, 63, 31]), 0, [31, 63, 31])).astype(int)
    return (r << 11) | (g << 5) | b


def _u565(v):
    return np.array([((v >> 11) & 31) / 31.0, ((v >> 5) & 63) / 63.0, (v & 31) / 31.0])


def dxt5(img):
    """img: float RGBA (h, w, 4), h и w кратны 4."""
    h, w = img.shape[:2]
    out = bytearray()
    for by in range(0, h, 4):
        for bx in range(0, w, 4):
            blk = img[by:by + 4, bx:bx + 4].reshape(16, 4)
            # альфа
            a = np.clip(np.round(blk[:, 3] * 255), 0, 255).astype(int)
            a0, a1 = int(a.max()), int(a.min())
            if a0 == a1:
                aidx = [0] * 16
                if a0 == 0:
                    a0, a1 = 0, 0
            else:
                pal = [a0, a1] + [((7 - i) * a0 + i * a1) // 7 for i in range(1, 7)]
                order = [0, 2, 3, 4, 5, 6, 7, 1]
                aidx = []
                for v in a:
                    best = min(range(8), key=lambda k: abs(pal[k] - v))
                    aidx.append(best)
            bits = 0
            for i, k in enumerate(aidx):
                bits |= (k & 7) << (3 * i)
            out += bytes([a0, a1]) + bits.to_bytes(6, 'little')
            # цвет: только видимые пиксели
            rgb = blk[:, :3]
            vis = blk[:, 3] > 0.02
            pts = rgb[vis] if vis.any() else rgb
            if len(pts) > 1:
                mean = pts.mean(0)
                cov_ = np.cov((pts - mean).T) if len(pts) > 2 else np.outer(pts[-1] - pts[0], pts[-1] - pts[0])
                try:
                    ev, evec = np.linalg.eigh(cov_)
                    axis = evec[:, -1]
                except Exception:
                    axis = np.array([1, 1, 1]) / np.sqrt(3)
                proj = (pts - mean) @ axis
                cmax = mean + axis * proj.max()
                cmin = mean + axis * proj.min()
            else:
                cmax = cmin = pts[0]
            c0, c1 = _c565(np.clip(cmax, 0, 1)), _c565(np.clip(cmin, 0, 1))
            if c0 < c1:
                c0, c1 = c1, c0
            if c0 == c1:
                idx = [0] * 16
            else:
                p0, p1 = _u565(c0), _u565(c1)
                pal = [p0, p1, (2 * p0 + p1) / 3, (p0 + 2 * p1) / 3]
                idx = [int(np.argmin([np.sum((c - q) ** 2) for q in pal])) for c in rgb]
            cb = 0
            for i, k in enumerate(idx):
                cb |= k << (2 * i)
            out += struct.pack('<HHI', c0, c1, cb)
    return bytes(out)


TEX_XDB = '''<?xml version="1.0" encoding="UTF-8"?>
<UITexture>
  <mipSW>-1</mipSW>
  <mipsNumber>1</mipsNumber>
  <generateMipChain>false</generateMipChain>
  <type>DXT5</type>
  <width>{w}</width>
  <height>{h}</height>
  <realWidth>{w}</realWidth>
  <realHeight>{h}</realHeight>
  <disableLODControl>false</disableLODControl>
  <alphaTex>true</alphaTex>
  <binaryFileSize>{size}</binaryFileSize>
  <binaryFile href="{name}.(UITexture).bin" />
  <sourceFile href="" />
  <sourceFileCRC>0</sourceFileCRC>
  <wrap>false</wrap>
</UITexture>
'''


def write_texture(folder, name, img, preview_dir=None):
    h, w = img.shape[:2]
    raw = dxt5(img)
    data = zlib.compress(b'\0\0\0\0' + struct.pack('<I', len(raw)) + raw, 9)
    open(os.path.join(folder, name + '.(UITexture).bin'), 'wb').write(data)
    open(os.path.join(folder, name + '.(UITexture).xdb'), 'w', encoding='utf-8').write(
        TEX_XDB.format(w=w, h=h, size=len(data), name=name))
    open(os.path.join(folder, name + '.Studio.(UISingleTexture).xdb'), 'w', encoding='utf-8').write(
        '<?xml version="1.0" encoding="UTF-8" ?>\n<UISingleTexture>\n\t<singleTexture href="%s.(UITexture).xdb" />\n</UISingleTexture>\n' % name)
    if preview_dir:
        Image.fromarray((np.clip(img, 0, 1) * 255).astype(np.uint8), 'RGBA').save(os.path.join(preview_dir, name + '.png'))
