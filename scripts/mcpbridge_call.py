#!/usr/bin/env python3
"""CLI for Xcode 27's mcpbridge (MCP over stdio → XPC → Xcode).

Requires: Xcode 27 beta running with the project window open, external
agents enabled (Settings → Intelligence), agent consent granted once.

Usage:
  mcpbridge_call.py list                          # names of all tools
  mcpbridge_call.py schema BuildProject           # input schema for a tool
  mcpbridge_call.py call XcodeListSchemes '{}'    # invoke a tool
  mcpbridge_call.py call RunCodeSnippet '{"code":"print(1+1)"}' 120

Exit codes: 0 ok, 1 rpc error/timeout, 2 usage.
"""
import json
import subprocess
import sys
import threading
import time

INIT = {
    "jsonrpc": "2.0", "id": 0, "method": "initialize",
    "params": {"protocolVersion": "2025-06-18", "capabilities": {},
               "clientInfo": {"name": "pacelli-bridge-cli", "version": "1.0"}},
}
INITIALIZED = {"jsonrpc": "2.0", "method": "notifications/initialized"}


def rpc(request, timeout=60):
    """Run handshake + one request against a fresh mcpbridge; return response."""
    proc = subprocess.Popen(
        ["xcrun", "mcpbridge"], stdin=subprocess.PIPE,
        stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True)
    responses = {}

    def reader():
        for line in proc.stdout:
            line = line.strip()
            if not line:
                continue
            try:
                msg = json.loads(line)
            except json.JSONDecodeError:
                continue
            if "id" in msg:
                responses[msg["id"]] = msg

    threading.Thread(target=reader, daemon=True).start()
    try:
        for msg in (INIT, INITIALIZED, request):
            proc.stdin.write(json.dumps(msg) + "\n")
            proc.stdin.flush()
        deadline = time.time() + timeout
        while time.time() < deadline and request["id"] not in responses:
            time.sleep(0.2)
    finally:
        proc.kill()
    return responses.get(request["id"])


def tools(timeout=60):
    resp = rpc({"jsonrpc": "2.0", "id": 1, "method": "tools/list"}, timeout)
    if not resp or "error" in (resp or {}):
        sys.exit(f"tools/list failed: {resp and resp.get('error')}")
    return resp["result"]["tools"]


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    cmd = sys.argv[1]

    if cmd == "list":
        for t in sorted(tools(), key=lambda t: t["name"]):
            desc = (t.get("description") or "").split("\n")[0][:90]
            print(f"{t['name']:35s} {desc}")
    elif cmd == "schema":
        name = sys.argv[2]
        for t in tools():
            if t["name"] == name:
                print(json.dumps(t.get("inputSchema", {}), indent=2))
                return
        sys.exit(f"no such tool: {name}")
    elif cmd == "call":
        name = sys.argv[2]
        args = json.loads(sys.argv[3]) if len(sys.argv) > 3 else {}
        timeout = int(sys.argv[4]) if len(sys.argv) > 4 else 60
        resp = rpc({"jsonrpc": "2.0", "id": 1, "method": "tools/call",
                    "params": {"name": name, "arguments": args}}, timeout)
        # Auto-retry once with the first offered tabIdentifier.
        if resp and "tabIdentifier is required" in json.dumps(resp) \
                and "tabIdentifier" not in args:
            import re
            m = re.search(r"tabIdentifier: (\w+)", json.dumps(resp))
            if m:
                args["tabIdentifier"] = m.group(1)
                resp = rpc({"jsonrpc": "2.0", "id": 1, "method": "tools/call",
                            "params": {"name": name, "arguments": args}}, timeout)
        if resp is None:
            sys.exit(f"timeout after {timeout}s (Xcode busy or consent pending?)")
        if "error" in resp:
            sys.exit(f"error: {json.dumps(resp['error'])}")
        result = resp["result"]
        for item in result.get("content", []):
            if item.get("type") == "text":
                txt = item["text"]
                try:
                    print(json.dumps(json.loads(txt), indent=2))
                except (json.JSONDecodeError, ValueError):
                    print(txt)
            else:
                print(f"[{item.get('type')} content]")
        if result.get("isError"):
            sys.exit(1)
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main()
