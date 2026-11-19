sub init()
    m.top.functionName = "run"
end sub

' Checks the channel's chat every 2.5 seconds and sends new messages to the screen.
sub run()
    seen = {}
    emote = CreateObject("roRegex", "\[emote:\d+:([^\]]+)\]", "")
    url = "https://kick.com/api/v2/channels/" + m.top.channelId + "/messages"
    failures = 0
    while m.top.running
        resp = httpGet(url, "application/json")
        j = invalid
        if resp.code = 200 and resp.body <> "" then j = ParseJson(resp.body)
        if j <> invalid and j.data <> invalid and j.data.messages <> invalid
            failures = 0
            msgs = j.data.messages
            msgs.SortBy("created_at")
            fresh = []
            for each mm in msgs
                id = mm.id
                if id <> invalid
                    id = id.ToStr()
                    if not seen.DoesExist(id)
                        seen[id] = true
                        name = "?"
                        color = "#53FC18"
                        if mm.sender <> invalid
                            if mm.sender.username <> invalid then name = mm.sender.username
                            if mm.sender.identity <> invalid and mm.sender.identity.color <> invalid then color = mm.sender.identity.color
                        end if
                        text = ""
                        if mm.content <> invalid then text = emote.ReplaceAll(mm.content, ":\1:")
                        fresh.Push({ name: name, color: color, text: text })
                    end if
                end if
            end for
            if fresh.Count() > 0 then m.top.messages = fresh
            if seen.Count() > 3000 then seen = {}
            m.top.status = ""
        else
            failures = failures + 1
            if failures = 3 then m.top.status = "Chat isn't loading (code " + resp.code.ToStr() + "). Still trying..."
        end if
        sleep(2500)
    end while
end sub
