sub init()
    m.top.functionName = "run"
end sub

' Checks every saved channel and reports who is live.
sub run()
    out = {}
    for each slug in m.top.channels
        r = fetchChannel(slug)
        info = liveInfo(r.json)
        info.ok = (r.json <> invalid)
        out[slug] = info
    end for
    m.top.result = out
end sub
