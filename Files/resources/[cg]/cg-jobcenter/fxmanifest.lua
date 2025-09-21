fx_version 'cerulean'
game 'gta5'

name 'cg-jobcenter'
author 'CG'
description 'Jobcenter UI for ESX using ox_lib and oxmysql'
version '1.0.0'

lua54 'yes'

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

ui_page 'ui/index.html'

files {
    'ui/index.html',
    'ui/style.css',
    'ui/app.js'
}

dependency {
    'ox_lib',
    'oxmysql'
}
