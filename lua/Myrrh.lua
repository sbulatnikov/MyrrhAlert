--------------------------------------------------------------------------------
-- MyrrhAlert / Myrrh.lua
-- Логика без интерфейса: сколько мирры у персонажа и хватает ли её.
--------------------------------------------------------------------------------
MA.Myrrh = {}
local Myrrh = MA.Myrrh

-- Сколько мирры у персонажа сейчас
function Myrrh.Amount()
	local id = avatar.GetCurrencyId( MA.CURRENCY )
	-- Ожидаем: пока у персонажа нет ни одной мирры, игра не находит эту валюту (nil) — считаем, что мирры 0
	if not id then return 0 end
	local info = avatar.GetCurrencyValue( id )
	-- Ожидаем: игра может не отдать количество (nil по документации) — считаем, что мирры 0
	if not info then return 0 end
	return info.value
end

-- Мирры (amount) меньше порога? Порог 0 выключает предупреждение.
function Myrrh.IsLow( amount )
	local threshold = MA.cfg.threshold
	return threshold > 0 and amount < threshold
end
