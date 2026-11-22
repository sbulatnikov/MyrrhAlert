--------------------------------------------------------------------------------
-- MyrrhAlert / Config.lua
-- Настройки — глобальные, одни на всех персонажей.
-- Файл: Mods/Configs/MyrrhAlert/user.cfg, блок global -> ... -> data:
--   ma = { version = 2, myrrh = <порог>, battery = <порог>, memory = <порог> }
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
	-- версия 1 хранила один порог мирры в поле threshold
	if c.myrrh == nil then c.myrrh = c.threshold end
	c.threshold = nil
	c.version = 2
	-- починка: порог в файле мог быть испорчен руками — тогда берём порог по умолчанию
	for _, r in ipairs( MA.RESOURCES ) do
		c[ r.key ] = Cfg.NormalizeThreshold( c[ r.key ] ) or r.default
	end
	MA.cfg = c
end

function Cfg.Save()
	local g = ReadSection()
	g.ma = MA.cfg
	userMods.SetGlobalConfigSection( common.GetAddonName(), g )
end

-- key — запас из MA.RESOURCES
function Cfg.SetThreshold( key, n )
	MA.cfg[ key ] = n
	Cfg.Save()
end
