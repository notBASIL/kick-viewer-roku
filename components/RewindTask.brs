sub init()
    m.top.functionName = "run"
end sub

' Finds the recording of the stream that is live right now, which can be rewound.
sub run()
    esc = CreateObject("roUrlTransfer").Escape(m.top.channel)
    resp = httpGet("https://kick.com/api/v2/channels/" + esc + "/videos", "application/json")
    j = invalid
    if resp.code = 200 and resp.body <> "" then j = ParseJson(resp.body)
    if j = invalid
        m.top.result = { error: "Rewind isn't available right now (code " + resp.code.ToStr() + ")." }
        return
    end if

    list = j
    if type(j) = "roAssociativeArray" and j.data <> invalid then list = j.data
    if type(list) <> "roArray"
        m.top.result = { error: "Rewind isn't available for this stream." }
        return
    end if

    src = ""
    for i = 0 to list.Count() - 1
        v = list[i]
        if v <> invalid and v.source <> invalid and v.source <> ""
            stillLive = (v.is_live = true)
            if not stillLive and i = 0 and (v.duration = invalid or v.duration = 0) then stillLive = true
            if stillLive
                src = v.source
                exit for
            end if
        end if
    end for

    if src = ""
        m.top.result = { error: "This streamer's rewind isn't ready yet. Try again in a minute." }
        return
    end if

    variants = []
    mresp = httpGet(src, "*/*")
    if mresp.code = 200 then variants = parseMaster(mresp.body, src)
    m.top.result = { url: src, variants: variants }
end sub
