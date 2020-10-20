; Socket class
;   Big thanks to GeekDude for remaking this.
;       Original script by GeekDude: https://github.com/G33kDude/Socket.ahk/blob/master/Socket.ahk
;        AHK Forum Post by GeekDude: https://www.autohotkey.com/boards/viewtopic.php?f=6&t=35120
; =====================================================================================================
; Methods:
;
;   obj.New(SockID, recvCB, sType)
;
;       - SockID is a friendly name for the socket for easy ID in the callback.  Access the SockID
;         by >>>     myID := obj.SockID
;
;       - recvCB is the callback function name used to capture the buffer when data is coming in.
;         Default func name and params:     RecvCB(buffer,EventType,s)
;
;       - sType is socket type.  Default type is TCP.  Specify anything else and you get UDP.
;         I haven't yet fully tested UDP.
;
;   obj.Connect(["domain_or_ip","port"])
;
;       - Connects to the specified domain/ip and port.
;
;   obj.Send(buffer) / obj.SendText(text, encoding:="UTF-8")
;
;       - Sends data.  Use obj.Send() to send raw data.  Use obj.SendText() to send plain text.
;
;   obj.Bind(["ip","port"])
;
;       - Usually used to start listening.  You must call obj.Listen() after obj.Bind().
;
;   obj.Listen()
;
;       - Listens on the interface/port specified with obj.Bind()
class Socket {
    Static WM_SOCKET := 0x9987, MSG_PEEK := 2
    Static FD_READ := 1, FD_ACCEPT := 8, FD_CLOSE := 32
    
    Blocking := True, BlockSleep := 50, Bound := False, sType := ""
    ProtocolId := 6 ; IPPROTO_TCP -- 17 = IPPROTOI_UDP
    SocketType := 1 ; SOCK_STREAM -- 2 (for UDP)
    timeFormat := "HH:mm:ss" ; not used yet
    recvCB := "RecvCB"
    SockID := ""
    
    __New(SockID := "", recvCB := "", sType := "", Socket := -1) {
        static Init := False ; maybe not static?
        
        this.SockID := SockID, this.sType := sType
        this.recvCB := (recvCB ? recvCB : "RecvCB")
        
        this.ProtocolId := (sType = "UDP" ? 17 : 6) ; TCP will be the default
        this.SocketType := (sType = "UDP" ?  2 : 1)
        
        if (!Init) {
            DllCall("LoadLibrary", "Str", "Ws2_32", "Ptr")
            WSAData := BufferAlloc(394+A_PtrSize)
            if (Error := DllCall("Ws2_32\WSAStartup", "UShort", 0x0202, "Ptr", WSAData))
                throw Exception("Error starting Winsock",, Error)
            if (NumGet(WSAData, 2, "UShort") != 0x0202)
                throw Exception("Winsock version 2.2 not available")
            Init := True
        }
        this.Socket := Socket
    }
    
    __Delete() {
        if (this.Socket != -1)
            this.Disconnect()
    }
    
    Connect(Address) {
        if (this.Socket != -1)
            throw Exception("Socket already connected")
        Next := pAddrInfo := this.GetAddrInfo(Address)
        while Next {
            ai_addrlen := NumGet(Next+0, 16, "UPtr")
            ai_addr := NumGet(Next+0, 16+(2*A_PtrSize), "Ptr")
            if ((this.Socket := DllCall("Ws2_32\socket", "Int", NumGet(Next+0, 4, "Int"), "Int", this.SocketType, "Int", this.ProtocolId, "UInt")) != -1) {
                if (DllCall("Ws2_32\WSAConnect", "UInt", this.Socket, "Ptr", ai_addr, "UInt", ai_addrlen, "Ptr", 0, "Ptr", 0, "Ptr", 0, "Ptr", 0, "Int") == 0) {
                    DllCall("Ws2_32\freeaddrinfo", "Ptr", pAddrInfo) ; TODO: Error Handling
                    return this.EventProcRegister(Socket.FD_READ | Socket.FD_CLOSE)
                }
                this.Disconnect()
            }
            Next := NumGet(Next+0, 16+(3*A_PtrSize), "Ptr")
        }
        throw Exception("Error connecting")
    }
    
    Bind(Address) {
        if (this.Socket != -1)
            throw Exception("Socket already connected")
        Next := pAddrInfo := this.GetAddrInfo(Address)
        
        while Next 
        {
            ai_addrlen := NumGet(Next+0, 16, "UPtr")
            ai_addr := NumGet(Next+0, 16+(2*A_PtrSize), "Ptr")
            if ((this.Socket := DllCall("Ws2_32\socket", "Int", NumGet(Next+0, 4, "Int"), "Int", this.SocketType, "Int", this.ProtocolId, "UInt")) != -1) {
                if (r1 := DllCall("Ws2_32\bind", "UInt", this.Socket, "Ptr", ai_addr, "UInt", ai_addrlen, "Int") == 0) {
                    DllCall("Ws2_32\freeaddrinfo", "Ptr", pAddrInfo) ; TODO: ERROR HANDLING
                    return this.EventProcRegister(Socket.FD_READ | Socket.FD_ACCEPT | Socket.FD_CLOSE)
                }
                this.Disconnect()
            }
            Next := NumGet(Next+0, 16+(3*A_PtrSize), "Ptr")
        }
        throw Exception("Error binding")
    }
    
    Listen(backlog := 32) {
        r1 := DllCall("Ws2_32\listen", "UInt", this.Socket, "Int", backlog)
        return (r1 == 0)
    }
    
    Accept() {
        if ((s := DllCall("Ws2_32\accept", "UInt", this.Socket, "Ptr", 0, "Ptr", 0, "Ptr")) == -1)
            throw Exception("Error calling accept",, this.GetLastError())
        Sock := Socket.New(this.SockID,,this.sType,s)
        Sock.ProtocolId := this.ProtocolId
        Sock.SocketType := this.SocketType
        Sock.EventProcRegister(Socket.FD_READ | Socket.FD_CLOSE)
        return Sock
    }
    
    Disconnect() {
        if (this.Socket == -1) ; Return 0 if not connected
            return 0
        
        this.EventProcUnregister() ; Unregister the socket event handler and close the socket
        if (DllCall("Ws2_32\closesocket", "UInt", this.Socket, "Int") == -1)
            throw Exception("Error closing socket",, this.GetLastError())
        this.Socket := -1
        return 1
    }
    
    MsgSize() {
        static FIONREAD := 0x4004667F
        if (DllCall("Ws2_32\ioctlsocket", "UInt", this.Socket, "UInt", FIONREAD, "UInt*", argp:=0) == -1)
            throw Exception("Error calling ioctlsocket",, this.GetLastError())
        return argp
    }
    
    Send(Buffer, Flags:=0) {
        if ((r := DllCall("Ws2_32\send", "UInt", this.Socket, "Ptr", Buffer.ptr, "Int", Buffer.size-1, "Int", Flags)) == -1)
            throw Exception("Error calling send",, this.GetLastError())
        return r
    }
    
    SendText(Text, Encoding:="UTF-8", Flags:=0) {
        Buffer := BufferAlloc(StrPut(Text, Encoding)) ; * ((Encoding="UTF-16"||Encoding="cp1200") ? 2 : 1))
        Length := StrPut(Text, Buffer, Encoding)
        return this.Send(Buffer)
    }
    
    Recv(BufSize:=0, Flags:=0) {
        while (!(Length := this.MsgSize()) && this.Blocking)
            Sleep this.BlockSleep
        if !Length
            return 0
        Buffer := BufferAlloc(BufSize := (!BufSize ? Length : BufSize))
        if ((r := DllCall("Ws2_32\recv", "UInt", this.Socket, "Ptr", Buffer.ptr, "Int", BufSize, "Int", Flags)) == -1)
            throw Exception("Error calling recv",, this.GetLastError())
        return Buffer
    }
    
    RecvText(Buffer, Encoding:="UTF-8") {
        if (Buffer) {
            txt := StrReplace(StrGet(Buffer, Buffer.Size, Encoding),"`r","")
            return StrReplace(txt,"`n","`r`n")
        } Else
            return ""
    }
    
    GetAddrInfo(Address) { ; TODO: Use GetAddrInfoW
        Host := Address[1], Port := Address[2]
        Hints := BufferAlloc(16+(4*A_PtrSize), 0)
        NumPut("Int", this.SocketType, Hints, 8,)
        NumPut("Int", this.ProtocolId, Hints, 12)
        if (Error := DllCall("Ws2_32\getaddrinfo", "AStr", Host, "AStr", Port, "Ptr", Hints.ptr, "Ptr*", Result:=0))
            throw Exception("Error calling GetAddrInfo",, Error)
        return Result ; address of ADDRINFO (or chain of) struct(s)
    }
    
    MsgMonitor(wParam, lParam, Msg, hWnd) {
        if (Msg != Socket.WM_SOCKET || wParam != this.Socket)
            return
        
        If IsFunc(RecvCB := this.recvCB) { ; data, date, EventType, socket
            if (lParam & Socket.FD_READ)
                %RecvCB%(this.Recv(), "read", this)
            else if (lParam & Socket.FD_ACCEPT)
                this.Accept(), %RecvCB%("", "accept", this)
            else if (lParam & Socket.FD_CLOSE)
                this.EventProcUnregister(), this.Disconnect(), %RecvCB%("", "close", this)
        }
    }
    
    EventProcRegister(lEvent) {
        this.AsyncSelect(lEvent)
        if !this.Bound {
            this.Bound := ObjBindMethod(this,"MsgMonitor")
            OnMessage Socket.WM_SOCKET, this.Bound ; register event function
        }
    }
    
    EventProcUnregister() {
        this.AsyncSelect(0)
        if this.Bound {
            OnMessage Socket.WM_SOCKET, this.Bound, 0 ; unregister event function
            this.Bound := False
        }
    }
    
    AsyncSelect(lEvent) {
        if (DllCall("Ws2_32\WSAAsyncSelect"
            , "UInt", this.Socket    ; s
            , "Ptr", A_ScriptHwnd    ; hWnd
            , "UInt", Socket.WM_SOCKET ; wMsg
            , "UInt", lEvent) == -1) ; lEvent
            throw Exception("Error calling WSAAsyncSelect ---> SockID: " this.SockID " / " this.Socket,, this.GetLastError())
    }
    
    GetLastError() {
        return DllCall("Ws2_32\WSAGetLastError")
    }
    
    SetBroadcast(Enable) { ; for UDP sockets only -- don't know what this does yet
        static SOL_SOCKET := 0xFFFF, SO_BROADCAST := 0x20
        if (DllCall("Ws2_32\setsockopt"
            , "UInt", this.Socket ; SOCKET s
            , "Int", SOL_SOCKET   ; int    level
            , "Int", SO_BROADCAST ; int    optname
            , "UInt*", !!Enable   ; *char  optval
            , "Int", 4) == -1)    ; int    optlen
            throw Exception("Error calling setsockopt",, this.GetLastError())
    }
}
