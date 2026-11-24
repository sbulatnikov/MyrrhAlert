#!/bin/sh
# Тесты MyrrhAlert на заглушках API игры: обычная сборка скриптов (без отладки) и отладочная
#   sh test/run.sh [папка для временных файлов]      по умолчанию out/test
# Нужны Python 3 и texlua или luajit (LUA=<путь> — указать свой интерпретатор, PYTHON=<путь> — свой Python).
# Подходит luajit.exe из игры: data\Mods\Docs\ModdingDocuments\LuaCompiler\luajit.exe
set -e
HERE=$(cd "$(dirname "$0")/.." && pwd)
TMP=${1:-$HERE/out/test}
PY=${PYTHON:-}
if [ -z "$PY" ]; then
	for c in python3 python; do
		if "$c" -c "import sys; sys.exit(sys.version_info[0] != 3)" 2>/dev/null; then PY=$c; break; fi
	done
fi
[ -n "$PY" ] || { echo "не найден Python 3 (можно указать PYTHON=<путь>)"; exit 1; }
if [ -z "$LUA" ]; then
	for c in texlua luajit; do
		if command -v "$c" >/dev/null 2>&1; then LUA=$c; break; fi
	done
fi
[ -n "$LUA" ] || { echo "не найден texlua или luajit (можно указать LUA=<путь>)"; exit 1; }
rm -rf "$TMP"; mkdir -p "$TMP/release" "$TMP/debug"
ALLODS_DEBUG=0 "$PY" "$HERE/tools/strip_debug.py" "$HERE/lua" "$TMP/release"
ALLODS_DEBUG=1 "$PY" "$HERE/tools/strip_debug.py" "$HERE/lua" "$TMP/debug"
for kind in release debug; do
	echo "== сборка: $kind"
	"$LUA" "$HERE/test/run.lua" "$HERE" "$TMP/$kind"
done
