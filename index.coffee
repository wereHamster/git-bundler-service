
{ spawn } = require 'child_process'
module.exports = (msg) ->
    if msg.cmd is 'zion:bootstrap'
        process.send cmd: 'zion:fork'
    else if msg.cmd is 'zion:fork'
        if msg.deploy
            spawn('deploy.sh', [ msg.deploy ]).on 'exit', (code) ->
                process.send 'zion:restart' if code is 0
        else
            require './app'
