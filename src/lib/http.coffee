###

dnschain
http://dnschain.org

Copyright (c) 2014 okTurtles Foundation

This Source Code Form is subject to the terms of the Mozilla Public
License, v. 2.0. If a copy of the MPL was not distributed with this
file, You can obtain one at http://mozilla.org/MPL/2.0/.

###

module.exports = (dnschain) ->
    # expose these into our namespace
    for k of dnschain.globals
        eval "var #{k} = dnschain.globals.#{k};"

    # Specifications listed here:
    # - https://wiki.namecoin.info/index.php?title=Welcome
    # - https://wiki.namecoin.info/index.php?title=Domain_Name_Specification#Importing_and_delegation
    # - https://wiki.namecoin.info/index.php?title=Category:NEP
    # - https://wiki.namecoin.info/index.php?title=Namecoin_Specification
    VALID_NMC_DOMAINS = /^[a-zA-Z]+\/.+/
    unblockSettings = gConf.get "unblock"
    if unblockSettings.enabled
        unblockUtils = require('./unblock/utils')(dnschain)
        unblockProxy = require 'http-proxy'

    class HTTPServer
        constructor: (@dnschain) -> # WARNING!!! This dnschain object IS NOT the same as dnschain everywhere else...
            # @log = @dnschain.log.child server: "HTTP"
            @log = gNewLogger 'HTTP'
            @log.debug gLineInfo "Loading HTTPServer..."

            @server = http.createServer(@callback.bind(@)) or gErr "http create"
            @server.on 'error', (err) -> gErr err
            @server.on 'sockegError', (err) -> gErr err
            @server.on 'close', -> gErr 'Client closed the connection early.'
            @server.listen gConf.get('http:port'), gConf.get('http:host') or gErr "http listen"
            # @server.listen gConf.get 'http:port') or gErr "http listen"
            @log.info gLineInfo('started HTTP'), gConf.get 'http'

            if unblockSettings.enabled
                @proxy = unblockProxy.createProxyServer {}
                @proxy.on "error", (err, req, res) ->
                    @log.error "HTTP tunnel failed: "+req.headers.host
                    res.writeHead 500
                    res.end()


        shutdown: ->
            @log.debug gLineInfo 'shutting down!'
            @server.close()

        # TODO: send a signed header proving the authenticity of our answer

        callback: (req, res) ->
            path = S(url.parse(req.url).pathname).chompLeft('/').s

            if unblockSettings.enabled and unblockUtils.isHijacked(req.headers.host)
                @proxy.web req, res, {target: "http://"+req.headers.host, secure:false}
                @log.debug gLineInfo "HTTP tunnel: "+req.headers.host
            else
                @log.debug gLineInfo('request'), {path:path, url:req.url}

                notFound = ->
                    res.writeHead 404,  'Content-Type': 'text/plain'
                    res.write "Not Found: #{path}"
                    res.end()

                unless VALID_NMC_DOMAINS.test path
                    @log.debug gLineInfo('ignoring request for:'), path
                    return notFound()

                @dnschain.nmc.resolve path, (err,result) =>
                    return notFound() if err
                    res.writeHead 200, 'Content-Type': 'application/json'
                    @log.debug gLineInfo('cb|resolve'), {path:path, result:result}
                    res.write result.value, "utf8"
                    res.end()
