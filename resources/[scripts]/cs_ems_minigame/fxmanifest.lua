fx_version 'cerulean'
game 'gta5'

author 'lwkjacob on discord'
version '2.0.0'
description 'Standalone EMS Mini-Game Script using ox_lib'

dependencies {
    'ox_lib'
}

shared_script '@ox_lib/init.lua'
shared_script 'config.lua'

client_scripts {
    'client/client.lua'
}

server_scripts {
    'server/server.lua'
}

