fx_version 'cerulean'
lua54 'yes'
game 'gta5'

name 'cg-blackmarket'
author 'cg'
description 'Black Market script using ESX + ox_lib + ox_inventory + ox_target + oxmysql'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    'shared/config.lua',
    'shared/locale.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua'
}

client_scripts {
    'client/main.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js'
}

dependencies {
    'oxmysql',
    'ox_lib',
    'ox_inventory',
    'ox_target'
}
