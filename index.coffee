
{ spawn } = require 'child_process'
module.exports = (msg) ->
    process.chdir process.env.APP

    if msg.cmd is 'zion:bootstrap'
        process.send cmd: 'zion:fork'; process.exit 0
    else if msg.cmd is 'zion:fork'
        if msg.deploy
            spawn('./deploy.sh', [ msg.deploy ]).on 'exit', (code) ->
                process.send cmd: 'zion:restart' if code is 0
                process.exit 0
        else
            require './app'
