sub init()
    m.list = m.top.findNode("channelList")
    m.statusLabel = m.top.findNode("status")
    m.lastUpdate = m.top.findNode("lastUpdate")
    m.video = m.top.findNode("video")
    m.infoBar = m.top.findNode("infoBar")
    m.infoName = m.top.findNode("infoName")
    m.infoTitle = m.top.findNode("infoTitle")
    m.infoSub = m.top.findNode("infoSub")
    m.chatPanel = m.top.findNode("chatPanel")
    m.chatRows = m.top.findNode("chatRows")
    m.chatStatus = m.top.findNode("chatStatus")
    m.toast = m.top.findNode("toast")
    m.toastText = m.top.findNode("toastText")
    m.toastTimer = m.top.findNode("toastTimer")
    m.optionsPanel = m.top.findNode("optionsPanel")
    m.optionsList = m.top.findNode("optionsList")
    m.refreshTimer = m.top.findNode("refreshTimer")

    m.list.observeField("itemSelected", "onItemSelected")
    m.optionsList.observeField("itemSelected", "onOptionSelected")
    m.video.observeField("state", "onVideoState")
    m.toastTimer.observeField("fire", "hideToast")
    m.refreshTimer.observeField("fire", "onRefreshTimer")

    m.liveSrc = { url: "", variants: [] }
    m.rewindSrc = invalid
    m.mode = "live"
    m.infoBase = ""
    m.rewindTask = invalid
    m.seekBackPending = false
    m.currentLabel = ""
    m.triedFallback = false
    m.liveData = {}
    m.order = []
    m.chatLines = []
    m.chatTask = invalid
    m.statusTask = invalid
    m.chatOn = (loadPref("chat", "on") = "on")

    m.favorites = loadFavorites()
    refreshList()
    m.list.setFocus(true)
    refreshStatus()
    m.refreshTimer.control = "start"
end sub

' ---------- saved settings ----------
function regSection() as object
    return CreateObject("roRegistrySection", "kickviewer")
end function

function loadPref(key as string, fallback as string) as string
    sec = regSection()
    if sec.Exists(key) then return sec.Read(key)
    return fallback
end function

sub savePref(key as string, value as string)
    sec = regSection()
    sec.Write(key, value)
    sec.Flush()
end sub

function loadFavorites() as object
    arr = ParseJson(loadPref("favs", "[]"))
    if arr = invalid then return []
    return arr
end function

sub saveFavorites()
    savePref("favs", FormatJson(m.favorites))
end sub

' ---------- helpers ----------
function fmtViewers(n as dynamic) as string
    if n = invalid then return "0"
    if n >= 1000
        return Str(Int(n / 100) / 10.0).Trim() + "K"
    end if
    return Str(n).Trim()
end function

function rokuColor(hex as dynamic) as string
    if hex <> invalid and Len(hex) = 7 and Left(hex, 1) = "#" then return "0x" + Mid(hex, 2) + "FF"
    return "0x53FC18FF"
end function

' ---------- channel list (live first) ----------
sub refreshList()
    keepSlug = ""
    idx = m.list.itemFocused
    if idx > 0 and idx < m.order.Count() then keepSlug = m.order[idx]

    live = []
    offline = []
    for each slug in m.favorites
        info = m.liveData[slug]
        if info <> invalid and info.live = true
            live.Push({ slug: slug, viewers: info.viewers })
        else
            offline.Push(slug)
        end if
    end for
    live.SortBy("viewers", "r")

    m.order = [""]
    for each l in live
        m.order.Push(l.slug)
    end for
    for each s in offline
        m.order.Push(s)
    end for

    content = CreateObject("roSGNode", "ContentNode")
    addItem = content.createChild("ContentNode")
    addItem.title = "+ Add a channel"
    addItem.addFields({ kind: "add", live: false, line2: "" })

    for i = 1 to m.order.Count() - 1
        slug = m.order[i]
        info = m.liveData[slug]
        node = content.createChild("ContentNode")
        node.title = slug
        subText = "Checking..."
        isLive = false
        if info <> invalid
            if info.live = true
                isLive = true
                subText = "LIVE  ·  " + fmtViewers(info.viewers) + " watching"
                if info.category <> "" then subText = subText + "  ·  " + info.category
                if info.title <> "" then subText = subText + "  ·  " + Left(info.title, 70)
            else if info.ok = true
                subText = "Offline"
            else
                subText = "Couldn't check"
            end if
        end if
        node.addFields({ kind: "channel", live: isLive, line2: subText })
    end for
    m.list.content = content

    if keepSlug <> ""
        for i = 1 to m.order.Count() - 1
            if m.order[i] = keepSlug then m.list.jumpToItem = i
        end for
    end if
end sub

sub refreshStatus()
    if m.favorites.Count() = 0 then return
    if m.statusTask <> invalid and m.statusTask.state = "run" then return
    m.statusTask = CreateObject("roSGNode", "StatusTask")
    m.statusTask.channels = m.favorites
    m.statusTask.observeField("result", "onStatusResult")
    m.statusTask.control = "RUN"
end sub

sub onStatusResult()
    r = m.statusTask.result
    if r = invalid then return
    m.liveData = r
    refreshList()
    t = CreateObject("roDateTime")
    t.ToLocalTime()
    mins = t.GetMinutes()
    minStr = mins.ToStr()
    if mins < 10 then minStr = "0" + minStr
    m.lastUpdate.text = "Updated " + t.GetHours().ToStr() + ":" + minStr + "  ·  refreshes every minute"
end sub

sub onRefreshTimer()
    if not m.video.visible then refreshStatus()
end sub

sub onItemSelected()
    idx = m.list.itemSelected
    if idx = 0
        showKeyboard()
    else
        playChannel(m.order[idx])
    end if
end sub

' ---------- keyboard ----------
sub showKeyboard()
    kb = CreateObject("roSGNode", "StandardKeyboardDialog")
    kb.title = "Add channels"
    kb.message = ["Type one streamer name, or paste several separated by commas (e.g. xqc, adinross, eaglegaming)."]
    kb.buttons = ["Add", "Cancel"]
    kb.observeField("buttonSelected", "onKeyboardButton")
    m.top.dialog = kb
end sub

sub onKeyboardButton()
    dlg = m.top.dialog
    if dlg = invalid then return
    if dlg.buttonSelected = 0
        names = parseNames(dlg.text)
        dlg.close = true
        added = 0
        for each name in names
            exists = false
            for each f in m.favorites
                if f = name then exists = true
            end for
            if not exists
                m.favorites.Push(name)
                added = added + 1
            end if
        end for
        if added > 0
            saveFavorites()
            refreshList()
            refreshStatus()
        end if
        if names.Count() = 1
            playChannel(names[0])
        else if names.Count() > 1
            m.statusLabel.text = "Added " + added.ToStr() + " channels. Checking who's live..."
        end if
    else
        dlg.close = true
    end if
    m.list.setFocus(true)
end sub

' Accepts one name, a list separated by commas/spaces/new lines,
' kick.com links, or Kick's followed-channels JSON (pulls out each "slug").
function parseNames(text as string) as object
    out = []
    seen = {}
    raw = []
    q = Chr(34)
    if Instr(1, text, q + "slug" + q) > 0
        slugRe = CreateObject("roRegex", q + "slug" + q + "\s*:\s*" + q + "([A-Za-z0-9_\-]+)" + q, "")
        for each mm in slugRe.MatchAll(text)
            raw.Push(mm[1])
        end for
    else
        raw = CreateObject("roRegex", "[\s,;]+", "").Split(text)
    end if
    linkRe = CreateObject("roRegex", "^(https?://)?(www\.)?kick\.com/", "i")
    atRe = CreateObject("roRegex", "^@", "")
    tailRe = CreateObject("roRegex", "[/?#].*$", "")
    for each r in raw
        n = LCase(r.Trim())
        n = linkRe.Replace(n, "")
        n = atRe.Replace(n, "")
        n = tailRe.Replace(n, "")
        if n <> "" and not seen.DoesExist(n)
            seen[n] = true
            out.Push(n)
        end if
    end for
    return out
end function

' ---------- loading a channel ----------
sub playChannel(name as string)
    m.statusLabel.text = "Loading " + name + "..."
    m.task = CreateObject("roSGNode", "KickTask")
    m.task.channel = name
    m.task.observeField("result", "onTaskResult")
    m.task.control = "RUN"
end sub

sub onTaskResult()
    r = m.task.result
    if r = invalid then return
    if r.error <> invalid and r.error <> ""
        m.statusLabel.text = r.error
        return
    end if
    m.statusLabel.text = ""
    variants = []
    if r.variants <> invalid then variants = r.variants
    m.liveSrc = { url: r.url, variants: variants }
    m.rewindSrc = invalid
    m.mode = "live"
    m.streamTitle = r.title
    m.channelId = r.channelId
    m.channelName = r.name
    m.triedFallback = false

    m.infoName.text = r.name
    m.infoTitle.text = r.title
    subText = fmtViewers(r.viewers) + " watching"
    if r.category <> invalid and r.category <> "" then subText = subText + "  ·  " + r.category
    m.infoBase = subText
    updateInfoHint()

    v = chooseVariant(loadPref("quality", "max"))
    playStream(v.url, v.label)
    applyLayout()
end sub

sub updateInfoHint()
    if m.mode = "rewind"
        m.infoSub.text = "REWIND  ·  Left/Right = move  ·  OK = pause  ·  Up = full screen  ·  * = back to live"
    else
        m.infoSub.text = m.infoBase + "      Up = full screen  ·  Left = rewind  ·  * = options"
    end if
end sub

function currentSrc() as object
    if m.mode = "rewind" and m.rewindSrc <> invalid then return m.rewindSrc
    return m.liveSrc
end function

' Picks the stream that matches the saved quality setting.
function chooseVariant(pref as string) as object
    src = currentSrc()
    vs = src.variants
    auto = { url: src.url, label: "Auto" }
    if pref = "auto" or vs.Count() = 0 then return auto
    if pref = "max" then return { url: vs[0].url, label: vs[0].label + " (highest)" }
    for each v in vs
        if v.label = pref then return { url: v.url, label: v.label }
    end for
    target = pref.ToInt()
    for each v in vs
        if v.height <= target then return { url: v.url, label: v.label }
    end for
    last = vs[vs.Count() - 1]
    return { url: last.url, label: last.label }
end function

sub playStream(url as string, label as string)
    content = CreateObject("roSGNode", "ContentNode")
    content.url = url
    content.streamFormat = "hls"
    content.title = m.streamTitle
    content.live = (m.mode = "live")
    m.currentLabel = label
    m.video.control = "stop"
    ' live: arrows come to the app (Left = rewind); rewind: Roku's own seek bar
    m.video.enableTrickPlay = (m.mode = "rewind")
    m.video.content = content
    m.video.visible = true
    m.video.control = "play"
    m.video.setFocus(true)
    if m.mode = "rewind"
        showToast("Rewind · " + label)
    else
        showToast("LIVE · " + label)
    end if
end sub

sub onVideoState()
    state = m.video.state
    if state = "playing" and m.mode = "rewind" and m.seekBackPending = true
        m.seekBackPending = false
        d = m.video.duration
        if d <> invalid and d > 90 then m.video.seek = d - 60
    else if state = "error"
        if m.currentLabel <> "Auto" and not m.triedFallback
            m.triedFallback = true
            playStream(currentSrc().url, "Auto")
            showToast("Locked quality failed, using Auto")
            return
        end if
        if m.mode = "rewind"
            showToast("Rewind failed, back to live")
            goLive()
            return
        end if
        m.statusLabel.text = "Playback error: " + m.video.errorMsg
        stopVideo()
    else if state = "finished"
        if m.mode = "rewind"
            goLive()
            return
        end if
        m.statusLabel.text = "Stream ended."
        stopVideo()
    end if
end sub

' ---------- rewind ----------
sub startRewind()
    if m.rewindTask <> invalid and m.rewindTask.state = "run" then return
    showToast("Loading rewind...")
    m.rewindTask = CreateObject("roSGNode", "RewindTask")
    m.rewindTask.channel = m.channelName
    m.rewindTask.observeField("result", "onRewindResult")
    m.rewindTask.control = "RUN"
end sub

sub onRewindResult()
    r = m.rewindTask.result
    if r = invalid or not m.video.visible then return
    if r.error <> invalid and r.error <> ""
        showToast(r.error)
        return
    end if
    variants = []
    if r.variants <> invalid then variants = r.variants
    m.rewindSrc = { url: r.url, variants: variants }
    m.mode = "rewind"
    m.seekBackPending = true
    m.triedFallback = false
    v = chooseVariant(loadPref("quality", "max"))
    playStream(v.url, v.label)
    updateInfoHint()
end sub

sub goLive()
    m.mode = "live"
    m.triedFallback = false
    v = chooseVariant(loadPref("quality", "max"))
    playStream(v.url, v.label)
    updateInfoHint()
end sub

sub toggleChat()
    m.chatOn = not m.chatOn
    if m.chatOn then savePref("chat", "on") else savePref("chat", "off")
    applyLayout()
    if m.chatOn then showToast("Chat on") else showToast("Full screen")
end sub

sub stopVideo()
    m.video.control = "stop"
    m.video.visible = false
    m.optionsPanel.visible = false
    m.infoBar.visible = false
    m.chatPanel.visible = false
    stopChat()
    hideToast()
    m.list.setFocus(true)
    refreshStatus()
end sub

' ---------- layout: full screen or video + chat ----------
sub applyLayout()
    if not m.video.visible then return
    if m.chatOn
        m.video.width = 1440
        m.video.height = 810
        m.infoBar.visible = true
        m.chatPanel.visible = true
        startChat()
    else
        m.video.width = 1920
        m.video.height = 1080
        m.infoBar.visible = false
        m.chatPanel.visible = false
        stopChat()
    end if
end sub

' ---------- chat ----------
sub startChat()
    if m.chatTask <> invalid then return
    m.chatLines = []
    m.chatRows.removeChildrenIndex(m.chatRows.getChildCount(), 0)
    if m.channelId = invalid or m.channelId = ""
        m.chatStatus.text = "Chat isn't available for this stream."
        return
    end if
    m.chatStatus.text = "Loading chat..."
    m.chatTask = CreateObject("roSGNode", "ChatTask")
    m.chatTask.channelId = m.channelId
    m.chatTask.running = true
    m.chatTask.observeField("messages", "onChatMessages")
    m.chatTask.observeField("status", "onChatStatus")
    m.chatTask.control = "RUN"
end sub

sub stopChat()
    if m.chatTask <> invalid
        m.chatTask.unobserveField("messages")
        m.chatTask.unobserveField("status")
        m.chatTask.running = false
        m.chatTask = invalid
    end if
end sub

sub onChatStatus()
    if m.chatTask = invalid then return
    s = m.chatTask.status
    if s <> "" then m.chatStatus.text = s
end sub

sub onChatMessages()
    if m.chatTask = invalid then return
    for each msg in m.chatTask.messages
        m.chatLines.Push(msg)
    end for
    while m.chatLines.Count() > 30
        m.chatLines.Shift()
    end while
    m.chatStatus.text = ""
    renderChat()
end sub

' Draws messages from the bottom up: colored name, message underneath.
sub renderChat()
    m.chatRows.removeChildrenIndex(m.chatRows.getChildCount(), 0)
    y = 1056
    for i = m.chatLines.Count() - 1 to 0 step -1
        msg = m.chatLines[i]
        body = m.chatRows.createChild("Label")
        body.font = "font:SmallestSystemFont"
        body.color = "0xE6EAEDFF"
        body.width = 424
        body.wrap = true
        body.maxLines = 4
        body.text = msg.text
        h = 0
        if msg.text <> "" then h = body.boundingRect().height

        y = y - h - 34
        if y < 96
            m.chatRows.removeChild(body)
            exit for
        end if
        name = m.chatRows.createChild("Label")
        name.font = "font:SmallestBoldSystemFont"
        name.color = rokuColor(msg.color)
        name.text = msg.name
        name.translation = [28, y]
        body.translation = [28, y + 30]
        y = y - 12
    end for
end sub

' ---------- options menu (chat + quality) ----------
sub showOptions()
    m.optionItems = []
    if m.mode = "rewind"
        m.optionItems.Push({ kind: "live", text: "Back to LIVE" })
    else
        m.optionItems.Push({ kind: "rewind", text: "Rewind (go back in stream)" })
    end if
    if m.chatOn
        m.optionItems.Push({ kind: "chat", text: "Full screen (hide chat)" })
    else
        m.optionItems.Push({ kind: "chat", text: "Show chat" })
    end if
    m.optionItems.Push({ kind: "q", pref: "max", text: "Quality: Highest (locked)" })
    for each v in currentSrc().variants
        m.optionItems.Push({ kind: "q", pref: v.label, text: "Quality: " + v.label })
    end for
    m.optionItems.Push({ kind: "q", pref: "auto", text: "Quality: Auto" })

    current = loadPref("quality", "max")
    content = CreateObject("roSGNode", "ContentNode")
    for each it in m.optionItems
        node = content.createChild("ContentNode")
        if it.kind = "q" and it.pref = current
            node.title = "> " + it.text
        else
            node.title = "   " + it.text
        end if
    end for
    m.optionsList.content = content
    m.optionsList.jumpToItem = 0
    m.optionsPanel.visible = true
    m.optionsList.setFocus(true)
end sub

sub hideOptions()
    m.optionsPanel.visible = false
    m.video.setFocus(true)
end sub

sub onOptionSelected()
    it = m.optionItems[m.optionsList.itemSelected]
    hideOptions()
    if it.kind = "chat"
        toggleChat()
        return
    else if it.kind = "rewind"
        startRewind()
        return
    else if it.kind = "live"
        goLive()
        return
    end if
    savePref("quality", it.pref)
    m.triedFallback = false
    v = chooseVariant(it.pref)
    playStream(v.url, v.label)
end sub

' ---------- on-screen message ----------
sub showToast(text as string)
    m.toastText.text = text
    m.toast.visible = true
    m.toastTimer.control = "stop"
    m.toastTimer.control = "start"
end sub

sub hideToast()
    m.toast.visible = false
end sub

' ---------- remote buttons ----------
function onKeyEvent(key as string, press as boolean) as boolean
    if not press then return false

    if m.optionsPanel.visible
        if key = "back" or key = "options"
            hideOptions()
            return true
        end if
        return false
    end if

    if m.video.visible
        if key = "back"
            if m.mode = "rewind"
                goLive()
            else
                stopVideo()
            end if
            return true
        else if key = "options"
            showOptions()
            return true
        else if key = "up"
            toggleChat()
            return true
        else if m.mode = "live" and (key = "left" or key = "rewind")
            startRewind()
            return true
        end if
        return false
    end if

    if key = "options"
        idx = m.list.itemFocused
        if idx > 0 and idx < m.order.Count()
            slug = m.order[idx]
            for i = 0 to m.favorites.Count() - 1
                if m.favorites[i] = slug
                    m.favorites.Delete(i)
                    exit for
                end if
            end for
            saveFavorites()
            m.liveData.Delete(slug)
            m.statusLabel.text = "Removed " + slug
            refreshList()
        end if
        return true
    end if
    return false
end function
