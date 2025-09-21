local Locales = {}

Locales.en = {
    open_market = 'Open Black Market',
    not_enough = 'Not enough funds',
    no_stock = 'Out of stock',
    bought_item = 'Purchased %sx %s',
    missing_license = 'You are missing required license',
    not_open = 'Dealer not available right now',
    restocked = 'Black market restocked',
}

Locales.es = {
    open_market = 'Abrir Mercado Negro',
    not_enough = 'Fondos insuficientes',
    no_stock = 'Sin stock',
    bought_item = 'Compraste %sx %s',
    missing_license = 'Falta la licencia requerida',
    not_open = 'Vendedor no disponible',
    restocked = 'Mercado negro reabastecido',
}

function _L(key, ...)
    local cfg = Config or {}
    local lang = (cfg.Locale and Locales[cfg.Locale]) and cfg.Locale or 'en'
    local str = Locales[lang][key] or key
    if select('#', ...) > 0 then
        return string.format(str, ...)
    end
    return str
end

return Locales
