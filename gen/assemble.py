"""Собирает папку аддона: виджеты, тексты, скрипты в cp1251, AddonDesc, проверка ссылок.

  python gen/assemble.py [папка аддона]     по умолчанию out/MyrrhAlert
"""
import os, re, sys, shutil

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
OUT = os.path.abspath(sys.argv[1]) if len(sys.argv) > 1 else os.path.join(ROOT, 'out', 'MyrrhAlert')
sys.path.insert(0, os.path.join(ROOT, 'tools'))  # своя копия: репозиторий собирается сам по себе
import strip_debug  # noqa: E402  — отладка только в сборке с ALLODS_DEBUG=1

NAME = 'MyrrhAlert'
VERSION = re.search(r'MA\.VERSION = "([^"]+)"', open(os.path.join(ROOT, 'lua', 'Util.lua'), encoding='utf-8').read()).group(1)
SCRIPTS = ['Util', 'Config', 'Myrrh', 'UI', 'Main']

# Надпись: по центру сверху, поверх игры, клики сквозь неё проходят
WARNING_TEXT = 'НЕДОСТАТОЧНО МИРРЫ'
WARNING_COLOR = '0xffff3b30'   # красный: это предупреждение, а не акцент интерфейса
WARNING_FONT_SIZE = 30
WARNING_TOP = 170              # отступ от верха экрана
WARNING_WIDTH, WARNING_HEIGHT = 900, 60


def write(rel, data):
    path = os.path.join(OUT, *rel.split('/'))
    os.makedirs(os.path.dirname(path), exist_ok=True)
    open(path, 'wb').write(data if isinstance(data, bytes) else data.encode('utf-8'))


def text(rel, s):
    """Тексты игры — UTF-16 LE с меткой порядка байтов."""
    write(rel, b'\xff\xfe' + s.encode('utf-16-le'))


shutil.rmtree(OUT, ignore_errors=True)

write('Widgets/MainForm.(WidgetForm).xdb', '''<?xml version="1.0" encoding="UTF-8" ?>
<WidgetForm>
	<Name>MainForm</Name>
	<Priority>1000</Priority>
	<Children>
		<Item href="Warning.(WidgetTextView).xdb" />
	</Children>
	<Placement>
		<X>
			<Pos>0</Pos>
			<Align>WIDGET_ALIGN_BOTH</Align>
		</X>
		<Y>
			<Pos>0</Pos>
			<Align>WIDGET_ALIGN_BOTH</Align>
		</Y>
	</Placement>
	<PickChildrenOnly>true</PickChildrenOnly>
	<Visible>true</Visible>
</WidgetForm>
''')

write('Widgets/Warning.(WidgetTextView).xdb', '''<?xml version="1.0" encoding="UTF-8" ?>
<WidgetTextView>
	<Name>Warning</Name>
	<Placement>
		<X>
			<Pos>0</Pos>
			<Size>%d</Size>
			<Align>WIDGET_ALIGN_CENTER</Align>
		</X>
		<Y>
			<Pos>%d</Pos>
			<Size>%d</Size>
		</Y>
	</Placement>
	<FormatFileRef href="../Texts/Warning.txt" />
	<TransparentInput>true</TransparentInput>
	<Visible>false</Visible>
</WidgetTextView>
''' % (WARNING_WIDTH, WARNING_TOP, WARNING_HEIGHT))

text('Texts/Warning.txt', '<html fontname="AllodsSystem" fontsize="%d" color="%s" alignx="center" aligny="middle" '
     'shadow="1" outline="1">%s</html>' % (WARNING_FONT_SIZE, WARNING_COLOR, WARNING_TEXT))
text('Texts/AddonName.txt', '%s v%s' % (NAME, VERSION))  # имя аддона в игре — всегда с версией
text('Texts/AddonDescription.txt', 'Предупреждает, когда мирры меньше порога (/myrrh)')

for s in SCRIPTS:
    src = open(os.path.join(ROOT, 'lua', s + '.lua'), 'rb').read().decode('utf-8')
    write('Scripts/%s.lua' % s, strip_debug.strip(src, where=s + '.lua').encode('cp1251'))

write('AddonDesc.(UIAddon).xdb', '''<?xml version="1.0" encoding="UTF-8" ?>
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
print('broken refs:', bad, '| files:', sum(len(fs) for _, _, fs in os.walk(OUT)))
sys.exit(1 if bad else 0)
