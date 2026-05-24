fx_version 'cerulean'
game 'gta5'

name        'mcSentinel'
description 'FiveM anti-cheat & admin monitoring system — NUI + oxmysql'
version     '1.0.0'
author      'Mcdikmen'
url         'https://github.com/Mcdikmen/mcSentinel'
repository  'https://github.com/Mcdikmen/mcSentinel'

lua54 'yes'

dependencies {
    'qbx_core',
    'oxmysql',
}

shared_scripts {
    'shared/config.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/db.lua',
    'server/events/admin.lua',
    'server/events/player.lua',
    'server/events/exploit.lua',
    'server/events/money.lua',
    'server/main.lua',
}

client_scripts {
    'client/main.lua',
    'client/nui.lua',
}

ui_page 'web/index.html'

files {
    'web/index.html',
    'web/css/style.css',
    'web/js/app.js',
}
