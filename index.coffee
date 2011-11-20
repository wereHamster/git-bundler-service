
{ spawn } = require 'child_process'
process.on 'message', (msg) ->
    if msg.cmd is 'zion:bootstrap'
        process.send 'zion:fork'
    else if msg.cmd is 'zion:fork'
        if msg.deploy
            spawn('deploy.sh', [ msg.deploy ]).on 'exit', (code) ->
                process.send 'zion:restart' if code is 0
        else
            require './app'
