"""Собирает папку аддона: ресурсы (build.py), скрипты в cp1251, AddonDesc, проверка ссылок.

  python gen/assemble.py [папка аддона]     по умолчанию out/MyrrhAlert
Предпросмотр текстур (PNG) кладётся в out/preview. Нужны Python 3, numpy и Pillow.
"""
import os, re, subprocess, sys, shutil

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
OUT = os.path.abspath(sys.argv[1]) if len(sys.argv) > 1 else os.path.join(ROOT, 'out', 'MyrrhAlert')
sys.path.insert(0, os.path.join(ROOT, 'tools'))  # своя копия: репозиторий собирается сам по себе
import strip_debug  # noqa: E402  — отладка только в сборке с ALLODS_DEBUG=1

NAME = 'MyrrhAlert'
VERSION = re.search(r'MA\.VERSION = "([^"]+)"', open(os.path.join(ROOT, 'lua', 'Util.lua'), encoding='utf-8').read()).group(1)
SCRIPTS = ['LibDnD', 'Util', 'Config', 'Stock', 'UI', 'Main']


def text(rel, s):
    """Тексты игры — UTF-16 LE с меткой порядка байтов."""
    open(os.path.join(OUT, *rel.split('/')), 'wb').write(b'\xff\xfe' + s.encode('utf-16-le'))


shutil.rmtree(OUT, ignore_errors=True)
subprocess.check_call([sys.executable, os.path.join(HERE, 'build.py'), OUT, os.path.join(ROOT, 'out', 'preview')])

text('Texts/AddonName.txt', '%s v%s' % (NAME, VERSION))  # имя аддона в игре — всегда с версией
text('Texts/AddonDescription.txt', 'Предупреждает, когда мирры, мана-батарей или модулей памяти меньше порога (/myrrh)')

sd = os.path.join(OUT, 'Scripts')
os.makedirs(sd, exist_ok=True)
for s in SCRIPTS:
    raw = open(os.path.join(ROOT, 'lua', s + '.lua'), 'rb').read()
    if s == 'LibDnD':
        data = raw  # чужая библиотека, уже в cp1251
    else:
        data = strip_debug.strip(raw.decode('utf-8'), where=s + '.lua').encode('cp1251')
    open(os.path.join(sd, s + '.lua'), 'wb').write(data)

open(os.path.join(OUT, 'AddonDesc.(UIAddon).xdb'), 'w', encoding='utf-8').write('''<?xml version="1.0" encoding="UTF-8" ?>
<UIAddon>
	<Name>%s</Name>
	<AutoStart>true</AutoStart>
	<userAddonInfo>
		<name href="Texts/AddonName.txt" />
		<description href="Texts/AddonDescription.txt" />
		<author>NoMercy</author>
		<version>%s</version>
	</userAddonInfo>
	<ScriptFileRefs>
%s	</ScriptFileRefs>
	<Form href="Widgets/MainForm.(WidgetForm).xdb" />
</UIAddon>
''' % (NAME, VERSION, ''.join('\t\t<Item href="Scripts/%s.lua" />\n' % s for s in SCRIPTS)))

# проверка ссылок: каждый href в .xdb ведёт на существующий файл
bad = 0
for root, _, files in os.walk(OUT):
    for f in files:
        if not f.endswith('.xdb'):
            continue
        p = os.path.join(root, f)
        for href in re.findall(r'href="([^"#]+)', open(p, encoding='utf-8').read()):
            if not os.path.exists(os.path.normpath(os.path.join(root, href))):
                print('BROKEN', os.path.relpath(p, OUT), '->', href)
                bad += 1

# все виджеты достижимы из MainForm
seen = set()


def walk(path):
    if path in seen:
        return
    seen.add(path)
    for href in re.findall(r'href="([^"#]+\.xdb)"', open(path, encoding='utf-8').read()):
        q = os.path.normpath(os.path.join(os.path.dirname(path), href))
        if os.path.exists(q):
            walk(q)


walk(os.path.join(OUT, 'AddonDesc.(UIAddon).xdb'))
wid = os.path.join(OUT, 'Widgets')
orphans = [f for f in os.listdir(wid) if f.endswith('.xdb') and os.path.join(wid, f) not in seen]
print('broken refs:', bad, '| orphan widgets:', orphans, '| files:', sum(len(fs) for _, _, fs in os.walk(OUT)))
sys.exit(1 if bad or orphans else 0)
