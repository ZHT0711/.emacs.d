#!/usr/bin/env python3
"""simple-mpv-audio-bridge.py — bridge mpv's Windows named pipe to TCP.

Used by simple-mpv-audio.el on Windows: the msys2 Emacs build cannot open
Windows named pipes (:family 'local unsupported), while mpv's IPC on Windows
only listens on a named pipe.  This script exposes that pipe on
127.0.0.1:<tcp-port> so Emacs can connect via plain TCP.

Usage: simple-mpv-audio-bridge.py <pipe-name> <tcp-port>
  <pipe-name>  mpv's --input-ipc-server name (without the \\.\pipe\ prefix)
  <tcp-port>   TCP port to listen on (127.0.0.1)

Notes on the relay loop:
  - A single synchronous ReadFile+WriteFile pair on the same pipe handle
    deadlocks, so reads are done with PeekNamedPipe (non-blocking) and
    select() on the TCP socket; commands from Emacs are never starved.
  - Requires Python on PATH (native Win32 build, e.g. msys2 ucrt64).
"""

import select
import socket
import sys
import _winapi

pipe_name, tcp_port = sys.argv[1], int(sys.argv[2])
BS = chr(92)
pipe_path = f"{BS}{BS}.{BS}pipe{BS}{pipe_name}"

pipe = _winapi.CreateFile(
    pipe_path,
    _winapi.GENERIC_READ | _winapi.GENERIC_WRITE,
    0, 0, _winapi.OPEN_EXISTING, 0, 0)

srv = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
srv.bind(("127.0.0.1", tcp_port))
srv.listen(1)
conn, _ = srv.accept()
srv.close()

while True:
    # Emacs -> mpv: forward TCP data to the named pipe
    try:
        r, _, _ = select.select([conn], [], [], 0.05)
        if r:
            data = conn.recv(65536)
            if not data:
                break
            _winapi.WriteFile(pipe, data)
    except Exception:
        break
    # mpv -> Emacs: forward pipe responses/events to TCP
    try:
        peek = _winapi.PeekNamedPipe(pipe, 65536)
        avail = peek[1] if isinstance(peek, tuple) else len(peek)
        if avail > 0:
            resp = _winapi.ReadFile(pipe, 65536)
            if resp:
                chunk = resp[0] if isinstance(resp, tuple) else resp
                if chunk:
                    conn.sendall(chunk)
    except Exception:
        break

conn.close()
