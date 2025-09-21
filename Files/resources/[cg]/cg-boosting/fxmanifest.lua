fx_version 'cerulean'
game 'gta5'

name 'cg-boosting'
author 'YourName'
version '0.1.0'
description 'Car Boosting Tablet for ESX using ox_lib / oxmysql'

lua54 'yes'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua'
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
    'html/script.js',
    'html/style.css'
}

dependency 'ox_lib'

-- ad
