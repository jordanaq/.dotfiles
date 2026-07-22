#!/usr/bin/env python3
"""
Temporary relay so the Firecrawl rootless-Docker container can reach host
services that still bind 127.0.0.1 (SearXNG :8888, Ollama :11434).

Rootless Docker with --disable-host-loopback means the container reaches the
host only via the host LAN IP, not 127.0.0.1/docker0. The real services bind
127.0.0.1, so we listen on the LAN IP (:8888/:11434 are free there) and forward
to loopback. Firecrawl's SEARXNG_ENDPOINT / OLLAMA_BASE_URL already point here.

STOP THIS before `sudo nixos-rebuild switch` (which moves the real services to
0.0.0.0):  pkill -f firecrawl-relay.py
After the rebuild the real services own 0.0.0.0:8888/11434 and this is unused.
"""
import re
import socket, threading, time

LAN = "192.168.50.13"
# SearXNG still binds 127.0.0.1:8888, so the relay owns :8888 on the LAN.
# Ollama now binds *:11434 (after nixos-rebuild), so the relay forwards a
# DISTINCT LAN port (11435) -> 127.0.0.1:11434 to avoid the bind conflict
# and still rewrite /chat -> /api/chat for Firecrawl's AI SDK.
PAIRS = [(8888, "127.0.0.1", 8888), (11435, "127.0.0.1", 11434)]


def relay(src, dst):
    try:
        while True:
            data = src.recv(65536)
            if not data:
                break
            dst.sendall(data)
    except Exception:
        pass
    finally:
        for s in (src, dst):
            try:
                s.close()
            except Exception:
                pass


def handle(client, th, tp):
    try:
        srv = socket.create_connection((th, tp), timeout=10)
    except Exception:
        client.close()
        return
    # Log + rewrite the request line (first bytes) for diagnostics.
    # Firecrawl's Vercel AI SDK ollama provider posts to /chat, /generate,
    # /embeddings, but Ollama's HTTP API expects /api/chat etc. The relay
    # inserts the /api prefix so Ollama answers instead of 404-ing.
    # Force Connection: close so Firecrawl opens a FRESH connection per
    # request (its SDK reuses keep-alive sockets, and a reused socket would
    # bypass this per-connection rewrite on the 2nd+ request).
    try:
        client.settimeout(3)
        first = client.recv(8192)
        if not first:
            client.close()
            return
        head, _, rest = first.partition(b"\r\n")
        line = head.decode(errors="replace")
        print(f"REQ ->{th}:{tp} {line[:160]}", flush=True)
        parts = line.split(" ")
        if len(parts) >= 2 and parts[1] in ("/chat", "/generate", "/embeddings", "/api/chat", "/api/generate", "/api/embeddings"):
            p = parts[1]
            newp = p if p.startswith("/api/") else "/api" + p
            parts[1] = newp
            head = " ".join(parts).encode()
        # Force Connection: close on the inbound headers.
        rest = re.sub(rb"(?i)Connection:[^\r\n]*\r\n", b"Connection: close\r\n", rest)
        if b"Connection:" not in rest:
            rest += b"Connection: close\r\n"
        first = head + b"\r\n" + rest
        # Drop the diagnostic timeout so the relayed streams never get cut.
        client.settimeout(None)
        srv.sendall(first)
    except Exception:
        client.close()
        return
    threading.Thread(target=relay, args=(client, srv), daemon=True).start()
    threading.Thread(target=relay, args=(srv, client), daemon=True).start()


def serve(lp, th, tp):
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    s.bind((LAN, lp))
    s.listen(128)
    print(f"relay {LAN}:{lp} -> {th}:{tp}", flush=True)
    while True:
        c, _ = s.accept()
        threading.Thread(target=handle, args=(c, th, tp), daemon=True).start()


for lp, th, tp in PAIRS:
    threading.Thread(target=serve, args=(lp, th, tp), daemon=True).start()

while True:
    time.sleep(3600)
