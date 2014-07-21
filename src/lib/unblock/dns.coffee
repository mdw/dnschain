module.exports = (dnschain) ->
    # expose these into our namespace
    for k of dnschain.globals
        eval "var #{k} = dnschain.globals.#{k};"

    dnsSettings = gConf.get "dns"
    @log = gNewLogger "Unblock"

    @hijack = (req, res) ->
        res.answer.push dns2.A {
            name: req.question[0].name
            address: dnsSettings.externalIP
            ttl: 120
        }
        res.header.aa = 1
        res.send()
        @log.debug "Hijacked "+req.question[0].name
        @log.debug res.answer[0]

    @