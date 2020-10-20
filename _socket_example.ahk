#Include _socket.ahk

Global g := ""

g := Gui.New()
g.OnEvent("close","gui_close")
g.Add("Edit","vMyEdit Multi w500 h500 ReadOnly","")
g.Show()

sListen := socket.new("listener")

; If on the same computer, you can't listen/send on the same port AND interface.
; Specify 0.0.0.0 for one interface (in this case for listening), and then specify
; 127.0.0.1 on the other interface for sending, otherwise you will get errors.

result := sListen.Bind(["0.0.0.0","1234"]) ; bind first ...
AppendText(g["MyEdit"].hwnd,">> Listen 0.0.0.0:1234 / " sListen.socket "`r`n`r`n")

sListen.Listen() ; then listen



sleep 2000



sSend := socket.New("sender")

r := sSend.Connect(["127.0.0.1","1234"]) ; connect first ...
AppendText(g["MyEdit"].hwnd,">> Connect 127.0.0.1:1234 / " sSend.socket "`r`n`r`n")

http := "
(
GET /download/2.0/version.txt HTTP/1.1
User-Agent: Mozilla/4.0 (compatible; MSIE5.01; Windows NT)
Host: www.this_is_a_test.com
Accept-Language: en-us
Accept-Encoding: gzip, deflate
Connection: Keep-Alive
... oh the possibilities ...


)" ; double CRLF at the end of HTTP traffic

Sleep 2000

sSend.SendText(http) ; then send

; obj.SendText() is useful for sending a plain text transmission.
; If you need to send binary data, use obj.Send(buffer), where you
;               create your own buffer and fill it before sending.

AppendText(g["MyEdit"].hwnd,">> Send 127.0.0.1:1234 / " sSend.socket "`r`n`r`n")

sSend.Disconnect() ; disconnect client
sListen.Disconnect() ; disconnect listener / server




RecvCB(buffer,EventType,s) {    ; RecvCB() is the default callback for network events
    ; buffer = buffer object, could be binary, could be text
    ;          on "accept" or "close" event, buffer = ""
    ; EventType = "read" / "accept" / "close"
    ; s = socket object, access any method or property
    
    data := s.RecvText(buffer)  ; buffer is a raw buffer, use .RecvText(buffer,Encoding:="UTF-8") to convert to text
    
    If (s.SockID = "listener") {
        myText := "======== CALLBACK / " eventType " / listener`r`n" data "`r`n========================`r`n`r`n"
        AppendText(g["MyEdit"].hwnd,myText)
    } Else If (s.SockID = "sender") {
        myText := "======== CALLBACK / " eventType " / senderr`n" data "`r`n========================`r`n`r`n"
        AppendText(g["MyEdit"].hwnd,myText)
    }
}

AppendText(EditHwnd, sInput, loc := "bottom") { ; Posted by TheGood: https://autohotkey.com/board/topic/52441-append-text-to-an-edit-control/#entry328342
    insertPos := (loc="bottom") ? SendMessage(0x000E, 0, 0,, "ahk_id " EditHwnd) : 0    ; WM_GETTEXTLENGTH
    r1 := SendMessage(0x00B1, insertPos, insertPos,, "ahk_id " EditHwnd)                ; EM_SETSEL - place cursor for insert
    r2 := SendMessage(0x00C2, False, StrPtr(sInput),, "ahk_id " EditHwnd)               ; EM_REPLACESEL - insert text at cursor
}

gui_close(*) {
    ExitApp
}