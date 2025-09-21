fx_version 'cerulean'
lua54 'yes'
game 'gta5'

name 'cg-lockpick'
author 'CodeGremlins'
description 'Simple vehicle lockpick using ox_target + ox_lib'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua'
}

client_scripts {
    'client/main.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua'
}

dependency 'ox_target'
dependency 'ox_lib'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js'
}
