sub init()
    m.top.functionName = "fetch"
end sub


sub fetch()
    name = m.top.channel
    r = fetchChannel(name)
    if r.code = 404
        m.top.result = { error: "Channel '" + name + "' not found." }
        return
    end if
    json = r.json
    if json = invalid
        m.top.result = { error: "Kick didn't answer (code " + r.code.ToStr() + "). It may be blocking the TV. Try again later." }
        return
    end if
    if json.livestream = invalid or json.playback_url = invalid or json.playback_url = ""
        m.top.result = { error: name + " is offline right now." }
        return
    end if

    info = liveInfo(json)
    title = info.title
    if title = "" then title = name

    master = json.playback_url
    variants = []
    mresp = httpGet(master, "*/*")
    if mresp.code = 200 then variants = parseMaster(mresp.body, master)

    channelId = ""
    if json.id <> invalid then channelId = json.id.ToStr()

    m.top.result = { url: master, title: title, variants: variants, channelId: channelId, viewers: info.viewers, category: info.category, name: name }
end sub
