--------------------------------------------------------------------------------
-- MyrrhAlert / Config.lua
-- Настройки — глобальные, одни на всех персонажей.
-- Файл: Mods/Configs/MyrrhAlert/user.cfg, блок global -> ... -> data:
--   ma = { version = 1, threshold = <число> }
-- Секция пишется целиком, поэтому перед записью читаем её заново.
--------------------------------------------------------------------------------
MA.Cfg = {}
local Cfg = MA.Cfg

local function ReadSection()
	local g = userMods.GetGlobalConfigSection( common.GetAddonName() )
	-- Ожидаем: при первом запуске секции настроек нет (nil) — начинаем с пустой
	return type( g ) == "table" and g or {}
end

-- Порог из любого значения: целое от 0 до THRESHOLD_MAX; nil, если это не число
function Cfg.NormalizeThreshold( v )
	local n = tonumber( v )
	if not n then return nil end
	return math.max( 0, math.min( MA.THRESHOLD_MAX, math.floor( n ) ) )
end

function Cfg.Load()
	local g = ReadSection()
	local c = type( g.ma ) == "table" and g.ma or {}
	c.version = 1
	-- починка: порог в файле мог быть испорчен руками — тогда берём порог по умолчанию
	c.threshold = Cfg.NormalizeThreshold( c.threshold ) or MA.THRESHOLD_DEFAULT
	MA.cfg = c
end

function Cfg.Save()
	local g = ReadSection()
	g.ma = MA.cfg
	userMods.SetGlobalConfigSection( common.GetAddonName(), g )
end

function Cfg.SetThreshold( n )
	MA.cfg.threshold = n
	Cfg.Save()
end
