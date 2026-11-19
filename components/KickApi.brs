' Shared network helpers used by the background tasks.

function httpGet(url as string, accept as string) as object
    ut = CreateObject("roUrlTransfer")
    port = CreateObject("roMessagePort")
    ut.SetMessagePort(port)
    ut.SetCertificatesFile("common:/certs/ca-bundle.crt")
    ut.InitClientCertificates()
    ut.RetainBodyOnError(true)
    ut.AddHeader("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0 Safari/537.36")
    ut.AddHeader("Accept", accept)
    ut.SetUrl(url)
    if ut.AsyncGetToString()
        msg = wait(15000, port)
        if type(msg) = "roUrlEvent"
            return { code: msg.GetResponseCode(), body: msg.GetString() }
        end if
        ut.AsyncCancel()
    end if
    return { code: -1, body: "" }
end function

' Returns { code, json } for a channel name.
function fetchChannel(name as string) as object
    esc = CreateObject("roUrlTransfer").Escape(name)
    resp = httpGet("https://kick.com/api/v2/channels/" + esc, "application/json")
    if resp.code <> 200
        resp = httpGet("https://kick.com/api/v1/channels/" + esc, "application/json")
    end if
    json = invalid
    if resp.code = 200 and resp.body <> "" then json = ParseJson(resp.body)
    return { code: resp.code, json: json }
end function

' Pulls the useful live info out of a channel response.
function liveInfo(json as dynamic) as object
    info = { live: false, viewers: 0, title: "", category: "" }
    if json = invalid then return info
    ls = json.livestream
    if ls = invalid then return info
    info.live = true
    if ls.viewer_count <> invalid then info.viewers = ls.viewer_count
    if ls.session_title <> invalid then info.title = ls.session_title
    if ls.categories <> invalid and ls.categories.Count() > 0
        if ls.categories[0].name <> invalid then info.category = ls.categories[0].name
    end if
    return info
end function

function resolveUrl(baseUrl as string, rel as string) as string
    if rel.Left(4) = "http" then return rel
    if rel.Left(1) = "/"
        m1 = CreateObject("roRegex", "^(https?://[^/]+)", "").Match(baseUrl)
        if m1.Count() > 1 then return m1[1] + rel
        return rel
    end if
    b = baseUrl
    q = Instr(1, b, "?")
    if q > 0 then b = Left(b, q - 1)
    for i = Len(b) to 1 step -1
        if Mid(b, i, 1) = "/" then return Left(b, i) + rel
    end for
    return rel
end function

' Reads Kick's master playlist and returns each quality level, best first.
function parseMaster(body as string, baseUrl as string) as object
    variants = []
    if body = "" then return variants
    reRes = CreateObject("roRegex", "RESOLUTION=(\d+)x(\d+)", "")
    reBw = CreateObject("roRegex", "(?:^|[:,])BANDWIDTH=(\d+)", "")
    reFps = CreateObject("roRegex", "FRAME-RATE=([\d.]+)", "")
    pending = invalid
    for each raw in body.Split(Chr(10))
        line = raw.Trim()
        if line.Left(18) = "#EXT-X-STREAM-INF:"
            pending = { height: 0, bandwidth: 0, fps: 0 }
            r = reRes.Match(line)
            if r.Count() > 2 then pending.height = r[2].ToInt()
            r = reBw.Match(line)
            if r.Count() > 1 then pending.bandwidth = r[1].ToInt()
            r = reFps.Match(line)
            if r.Count() > 1 then pending.fps = r[1].ToFloat()
        else if pending <> invalid and line <> "" and line.Left(1) <> "#"
            if pending.height > 0
                label = pending.height.ToStr() + "p"
                if pending.fps >= 50 then label = label + "60"
                pending.label = label
                pending.url = resolveUrl(baseUrl, line)
                variants.Push(pending)
            end if
            pending = invalid
        end if
    end for
    variants.SortBy("bandwidth", "r")
    return variants
end function

