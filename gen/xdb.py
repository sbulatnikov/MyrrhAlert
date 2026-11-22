"""Запись ресурсов аддона: виджеты (*.xdb), тексты (UTF-16LE), текстуры."""
import os
import tex as T

ROOT = None          # папка аддона
WID = None           # Widgets
TEXDIR = None        # Widgets/Textures
TXT = None           # Texts
PREVIEW = None
ICONS = []           # (key, name) для группы Icons
_written = set()


def setup(root, preview=None):
    global ROOT, WID, TEXDIR, TXT, PREVIEW
    ROOT = root
    WID = os.path.join(root, 'Widgets')
    TEXDIR = os.path.join(WID, 'Textures')
    TXT = os.path.join(root, 'Texts')
    PREVIEW = preview
    for d in (WID, TEXDIR, TXT) + ((preview,) if preview else ()):
        os.makedirs(d, exist_ok=True)


def esc(s):
    return s.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;').replace('"', '&quot;')


# ------------------------------------------------------------------ тексты

def argb(c, a=255):
    c = c.lstrip('#')
    return '0x%02x%s' % (a, c.lower())


def text_file(name, content):
    path = os.path.join(TXT, name + '.txt')
    open(path, 'wb').write(b'\xff\xfe' + content.encode('utf-16-le'))
    return '../Texts/%s.txt' % name


def fmt(name, font, size, color, alignx='left', aligny='middle', tag='value', literal=None, shadow=1, outline=0):
    attrs = 'fontname="%s" fontsize="%d" color="%s" alignx="%s" aligny="%s" shadow="%d"' % (
        font, size, argb(color), alignx, aligny, shadow)
    if outline:
        attrs += ' outline="%d"' % outline
    body = esc(literal) if literal is not None else '<r name="%s"/>' % tag
    return text_file(name, '<html %s>%s</html>' % (attrs, body))


# ------------------------------------------------------------------ текстуры

def _tex(name, img):
    if name in _written:
        return
    _written.add(name)
    T.write_texture(TEXDIR, name, img, PREVIEW)


def stretch(name, img):
    _tex(name, img)
    fn = '%s.Stretch.(WidgetLayerSimpleTexture).xdb' % name
    open(os.path.join(TEXDIR, fn), 'w', encoding='utf-8').write(
        '<?xml version="1.0" encoding="UTF-8" ?>\n<WidgetLayerSimpleTexture>\n\t<Color>0xffffffff</Color>\n'
        '\t<Grayed>false</Grayed>\n\t<BlendEffect>BLEND_EFFECT_ALPHABLND</BlendEffect>\n\t<flatPlacement>false</flatPlacement>\n'
        '\t<textureItem href="%s.Studio.(UISingleTexture).xdb" />\n\t<Scaling>true</Scaling>\n</WidgetLayerSimpleTexture>\n' % name)
    return 'Textures/' + fn


def frame(name, img, e):
    _tex(name, img)
    h, w = img.shape[:2]
    fn = '%s.Frame_%d_%d_%d_%d.(WidgetLayerTiledTexture).xdb' % (name, e, e, e, e)
    open(os.path.join(TEXDIR, fn), 'w', encoding='utf-8').write(
        '<?xml version="1.0" encoding="UTF-8" ?>\n<WidgetLayerTiledTexture>\n\t<Color>0xffffffff</Color>\n'
        '\t<Grayed>false</Grayed>\n\t<BlendEffect>BLEND_EFFECT_ALPHABLND</BlendEffect>\n\t<flatPlacement>false</flatPlacement>\n'
        '\t<textureItem href="%s.Studio.(UISingleTexture).xdb" />\n\t<Layout>\n'
        '\t\t<LeftX>%d</LeftX>\n\t\t<MiddleX>%d</MiddleX>\n\t\t<RightX>%d</RightX>\n'
        '\t\t<TopY>%d</TopY>\n\t\t<MiddleY>%d</MiddleY>\n\t\t<BottomY>%d</BottomY>\n\t</Layout>\n</WidgetLayerTiledTexture>\n'
        % (name, e, w - 2 * e, e, e, h - 2 * e, e))
    return 'Textures/' + fn


def icon(key, name, img):
    """Текстура в группе Icons (меняется из Lua через SetBackgroundTexture)."""
    href = stretch(name, img)
    open(os.path.join(TEXDIR, '%s.(UITextureElement).xdb' % name), 'w', encoding='utf-8').write(
        '<?xml version="1.0" encoding="UTF-8" ?>\n<UITextureElement>\n\t<singleTexture href="%s.(UITexture).xdb#xpointer(/UITexture)" />\n'
        '\t<permanentCache>0</permanentCache>\n</UITextureElement>\n' % name)
    if key not in [k for k, _ in ICONS]:
        ICONS.append((key, name))
    return href


def write_icon_group():
    items = ''.join('\t\t<Item>\n\t\t\t<name>%s</name>\n\t\t\t<textureItem href="%s.(UITextureElement).xdb" />\n\t\t</Item>\n'
                    % (k, n) for k, n in ICONS)
    open(os.path.join(TEXDIR, 'Icons.(UIRelatedTextures).xdb'), 'w', encoding='utf-8').write(
        '<?xml version="1.0" encoding="UTF-8" ?>\n<UIRelatedTextures>\n\t<Items>\n%s\t</Items>\n</UIRelatedTextures>\n' % items)


# ------------------------------------------------------------------ виджеты

def placement(x=0, y=0, w=None, h=None, ax=None, ay=None, hx=None, hy=None):
    def axis(tag, pos, size, al, high):
        s = '\t\t<%s>\n' % tag
        if pos is not None and al != 'WIDGET_ALIGN_HIGH':
            s += '\t\t\t<Pos>%d</Pos>\n' % pos
        if size is not None:
            s += '\t\t\t<Size>%d</Size>\n' % size
        if al:
            s += '\t\t\t<Align>%s</Align>\n' % al
        if high is not None:
            s += '\t\t\t<HighPos>%d</HighPos>\n' % high
        return s + '\t\t</%s>\n' % tag
    return '\t<Placement>\n' + axis('X', x, w, ax, hx) + axis('Y', y, h, ay, hy) + '\t</Placement>\n'


def _children(children):
    if not children:
        return ''
    return '\t<Children>\n' + ''.join('\t\t<Item href="%s" />\n' % c for c in children) + '\t</Children>\n'


def _write(kind, name, body, fname=None):
    fn = '%s.(%s).xdb' % (fname or name, kind)
    open(os.path.join(WID, fn), 'w', encoding='utf-8').write(
        '<?xml version="1.0" encoding="UTF-8" ?>\n<%s>\n\t<Name>%s</Name>\n%s</%s>\n' % (kind, name, body, kind))
    return fn


def common(visible=True, transparent=False, pick_children=False, priority=None, pointing=None, force_pointing=None,
           wheel=None, fade=None, clip=False):
    s = ''
    if priority is not None:
        s += '\t<Priority>%d</Priority>\n' % priority
    if pick_children:
        s += '\t<PickChildrenOnly>true</PickChildrenOnly>\n'
    if transparent:
        s += '\t<TransparentInput>true</TransparentInput>\n'
    if pointing:
        s += '\t<reactionOnPointing>%s</reactionOnPointing>\n' % pointing
    if force_pointing:
        s += '\t<forceReactionOnPointing>%s</forceReactionOnPointing>\n' % force_pointing
    if wheel:
        s += '\t<reactionWheelUp>%s</reactionWheelUp>\n\t<reactionWheelDown>%s</reactionWheelDown>\n' % wheel
    if clip:
        s += '\t<clipContent>true</clipContent>\n'
    if not visible:
        s += '\t<Visible>false</Visible>\n'
    return s


def panel(name, pl, back=None, children=(), fname=None, **kw):
    body = pl
    if back:
        body += '\t<BackLayer href="%s" />\n' % back
    body += _children(children) + common(**kw)
    return _write('WidgetPanel', name, body, fname)


def form(name, children):
    body = _children(children) + placement(0, 0, None, None, 'WIDGET_ALIGN_BOTH', 'WIDGET_ALIGN_BOTH') + \
        '\t<PickChildrenOnly>true</PickChildrenOnly>\n\t<Visible>true</Visible>\n'
    body = '\t<Priority>1000</Priority>\n' + body
    return _write('WidgetForm', name, body)


def textview(name, pl, fmt_ref, fname=None, multiline=False, transparent=True, **kw):
    body = pl
    if multiline:
        body += '\t<TextStyle>\n\t\t<multiline>true</multiline>\n\t\t<wrapText>true</wrapText>\n\t</TextStyle>\n'
    body += '\t<FormatFileRef href="%s" />\n' % fmt_ref
    body += common(transparent=transparent, **kw)
    return _write('WidgetTextView', name, body, fname)


def button(name, pl, variants, children=(), fname=None, **kw):
    """variants: [{normal, hover, pressed, disabled, text, fmt, fmt_dis, reaction}]"""
    body = pl + '\t<IgnoreDblClick>true</IgnoreDblClick>\n\t<TextTag>button_label</TextTag>\n\t<Variants>\n'
    for v in variants:
        body += '\t\t<Item>\n'
        if v.get('text'):
            body += '\t\t\t<TextFileRef href="%s" />\n' % v['text']
        if v.get('hover'):
            body += '\t\t\t<LayerHighlight href="%s" />\n' % v['hover']
        body += '\t\t\t<PushedOffset x="0" y="%d" />\n' % v.get('push', 1)
        body += '\t\t\t<StateNormal>\n\t\t\t\t<LayerMain href="%s" />\n' % v['normal']
        if v.get('fmt'):
            body += '\t\t\t\t<FormatFileRef href="%s" />\n' % v['fmt']
        body += '\t\t\t</StateNormal>\n'
        body += '\t\t\t<StatePushed>\n\t\t\t\t<LayerMain href="%s" />\n\t\t\t</StatePushed>\n' % v.get('pressed', v['normal'])
        body += '\t\t\t<StateDisabled>\n\t\t\t\t<LayerMain href="%s" />\n' % v.get('disabled', v['normal'])
        if v.get('fmt_dis') or v.get('fmt'):
            body += '\t\t\t\t<FormatFileRef href="%s" />\n' % (v.get('fmt_dis') or v['fmt'])
        body += '\t\t\t</StateDisabled>\n'
        if v.get('reaction'):
            body += '\t\t\t<Reaction>%s</Reaction>\n\t\t\t<ReactionOnUp>true</ReactionOnUp>\n' % v['reaction']
        if v.get('rclick'):
            body += '\t\t\t<ReactionRightClick>%s</ReactionRightClick>\n' % v['rclick']
        body += '\t\t</Item>\n'
    body += '\t</Variants>\n\t<TextStyle>\n\t\t<Align>ALIGNY_MIDDLE</Align>\n\t</TextStyle>\n'
    body += _children(children) + common(**kw)
    return _write('WidgetButton', name, body, fname)


def editline(name, pl, fmt_ref, cursor, selection, maxlen, enter, esc_, focus=None, changed=None, filter_alias=None,
             align='left', fname=None):
    body = pl
    body += '\t<Cursor1Layer href="%s" />\n\t<Cursor2Layer href="%s" />\n' % (cursor, cursor)
    body += '\t<CursorWidth>1</CursorWidth>\n\t<CursorChangeTimeMs>500</CursorChangeTimeMs>\n'
    body += '\t<ReactionEnter>%s</ReactionEnter>\n\t<ReactionEsc>%s</ReactionEsc>\n' % (enter, esc_)
    if focus:
        body += '\t<reactionFocusChanged>%s</reactionFocusChanged>\n' % focus
    if changed:
        body += '\t<ReactionChanged>%s</ReactionChanged>\n' % changed
    body += ('\t<TextStyle>\n\t\t<multiline>false</multiline>\n\t\t<wrapText>false</wrapText>\n\t\t<ellipsis>false</ellipsis>\n'
             '\t\t<Align>ALIGNY_MIDDLE</Align>\n\t</TextStyle>\n')
    body += '\t<isPassword>false</isPassword>\n\t<maxSymbolsCount>%d</maxSymbolsCount>\n' % maxlen
    if filter_alias:
        body += '\t<filterAlias>%s</filterAlias>\n' % filter_alias
    body += '\t<FormatFileRef href="%s" />\n\t<selectionLayer href="%s" />\n' % (fmt_ref, selection)
    return _write('WidgetEditLine', name, body, fname)


def scroll_container(name, pl, scrollbar, interval=0):
    body = pl + '\t<PickChildrenOnly>true</PickChildrenOnly>\n\t<IgnoreDblClick>true</IgnoreDblClick>\n'
    body += '\t<widgetsArrangement>WIDGETS_ARRANGEMENT_T2B</widgetsArrangement>\n\t<elementsInterval>%d</elementsInterval>\n' % interval
    body += '\t<scrollBar href="%s" />\n' % scrollbar
    return _write('WidgetScrollableContainer', name, body)


def glide_scrollbar(name, pl, inc, dec, slider):
    body = pl + '\t<incButton href="%s" />\n\t<decButton href="%s" />\n\t<slider href="%s" />\n' % (inc, dec, slider)
    return _write('WidgetGlideScrollBar', name, body)


def glide_slider(name, pl, thumb, step):
    body = pl + '\t<PickChildrenOnly>false</PickChildrenOnly>\n\t<IgnoreDblClick>true</IgnoreDblClick>\n'
    body += '\t<sliderButton href="%s" />\n\t<moveArrangement>WIDGETS_ARRANGEMENT_T2B</moveArrangement>\n\t<discreteStep>%d</discreteStep>\n' % (thumb, step)
    return _write('WidgetGlideSlider', name, body)
