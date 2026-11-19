sub init()
    m.bg = m.top.findNode("bg")
    m.dot = m.top.findNode("dot")
    m.name = m.top.findNode("name")
    m.line2 = m.top.findNode("sub")
end sub

sub onContent()
    c = m.top.itemContent
    if c = invalid then return
    m.name.text = c.title
    kind = c.getField("kind")
    if kind = "add"
        m.dot.visible = false
        m.line2.text = ""
        m.name.translation = [32, 22]
        return
    end if
    m.name.translation = [64, 6]
    m.dot.visible = true
    if c.getField("live") = true
        m.dot.blendColor = "0xFF4655FF"
    else
        m.dot.blendColor = "0x4A5258FF"
    end if
    m.line2.text = c.getField("line2")
end sub

sub onFocus()
    p = m.top.focusPercent
    m.bg.opacity = p
    if p > 0.5
        m.name.color = "0x0E1114FF"
        m.line2.color = "0x3A4248FF"
    else
        m.name.color = "0xEEEEEEFF"
        m.line2.color = "0x8A949CFF"
    end if
end sub
