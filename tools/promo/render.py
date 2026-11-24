"""Промо-карточки MyrrhAlert: tools/promo/cards.html -> release/promo/*.png (1600x900).

  python tools/promo/render.py

Нужен Chrome или Edge: страница снимается в режиме без окна. Свой путь к браузеру — переменная BROWSER.
"""
import os, pathlib, subprocess, sys, tempfile

HERE = pathlib.Path(__file__).resolve().parent
OUT = HERE.parent.parent / 'release' / 'promo'
CARDS = ['MyrrhAlert-1-cover', 'MyrrhAlert-2-stock', 'MyrrhAlert-3-settings']
BROWSERS = [os.environ.get('BROWSER'),
            r'C:\Program Files\Google\Chrome\Application\chrome.exe',
            r'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe',
            'google-chrome', 'chromium']


def browser():
    for b in BROWSERS:
        if b and (os.path.isfile(b) or os.sep not in b and subprocess.run(['which', b], capture_output=True).returncode == 0):
            return b
    sys.exit('не найден Chrome или Edge (можно указать BROWSER=<путь>)')


def main():
    exe = browser()
    OUT.mkdir(parents=True, exist_ok=True)
    page = (HERE / 'cards.html').as_uri()
    with tempfile.TemporaryDirectory() as profile:  # свой пустой профиль: не трогаем браузер пользователя
        for i, name in enumerate(CARDS, 1):
            png = OUT / (name + '.png')
            subprocess.run([exe, '--headless=new', '--disable-gpu', '--hide-scrollbars', '--force-device-scale-factor=1',
                            '--user-data-dir=' + profile, '--window-size=1600,900', '--screenshot=' + str(png),
                            '%s?card=%d' % (page, i)], check=True, capture_output=True)
            print(png.name, png.stat().st_size, 'байт')


if __name__ == '__main__':
    main()
