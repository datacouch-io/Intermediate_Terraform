#!/usr/bin/env python3
"""Render a captured terminal transcript to a terminal-styled HTML page.

The .txt inputs under artifacts/*/output/ are real captured runs. This turns one
into an image-able page so labs whose visible result is CLI output still get a
screenshot. It adds no content -- it only styles what was captured.

Usage: render_terminal.py <input.txt> <output.html> "<window title>"
"""
import html
import re
import sys

PASS = re.compile(r"^(PASS\b.*)$")
FAIL = re.compile(r"^(FAIL\b.*)$")
HEAD = re.compile(r"^(===.*===|#{1,3} .*)$")
ERRL = re.compile(r"^(\s*(Error|Warning):.*)$")
PROMPT = re.compile(r"^(\$ |> )(.*)$")
PLUS = re.compile(r"^(\s*\+ .*)$")
MINUS = re.compile(r"^(\s*- .*)$")
TILDE = re.compile(r"^(\s*~ .*)$")
SUMMARY = re.compile(r"^(.*(Apply complete|Destroy complete|Plan:|ALL CHECKS PASSED|FAILURES ABOVE).*)$")


def line_html(raw):
    e = html.escape(raw)
    if PASS.match(raw):
        return f'<span class="pass">{e}</span>'
    if FAIL.match(raw):
        return f'<span class="fail">{e}</span>'
    if HEAD.match(raw):
        return f'<span class="head">{e}</span>'
    if ERRL.match(raw):
        return f'<span class="err">{e}</span>'
    m = PROMPT.match(raw)
    if m:
        return (f'<span class="prompt">{html.escape(m.group(1))}</span>'
                f'<span class="cmd">{html.escape(m.group(2))}</span>')
    if SUMMARY.match(raw):
        return f'<span class="summary">{e}</span>'
    if PLUS.match(raw):
        return f'<span class="plus">{e}</span>'
    if MINUS.match(raw):
        return f'<span class="minus">{e}</span>'
    if TILDE.match(raw):
        return f'<span class="tilde">{e}</span>'
    return e


def render(src, out, title):
    with open(src) as fh:
        # Strip any ANSI that survived, and trailing blank lines.
        text = re.sub(r"\x1b\[[0-9;]*m", "", fh.read()).rstrip("\n")
    body = "\n".join(line_html(l) for l in text.split("\n"))
    page = f"""<!doctype html>
<meta charset="utf-8">
<title>{html.escape(title)}</title>
<style>
  /* qlmanage renders this to a SQUARE thumbnail. Centring the window means the
     leftover space becomes symmetric padding that reads as a desktop backdrop,
     rather than a large empty area below the content. */
  html,body {{ margin:0; padding:0; background:#0c0f14; min-height:100vh; }}
  body {{ display:flex; align-items:center; justify-content:center; box-sizing:border-box;
          padding:26px; }}
  .win {{ width:100%; border-radius:9px; overflow:hidden;
          box-shadow:0 6px 26px rgba(0,0,0,.45); border:1px solid #2b333d; }}
  .bar {{ background:#222933; padding:9px 14px; display:flex; align-items:center; gap:8px;
          border-bottom:1px solid #2b333d; }}
  .dot {{ width:11px; height:11px; border-radius:50%; display:inline-block; }}
  .r{{background:#ff5f57}} .y{{background:#febc2e}} .g{{background:#28c840}}
  .title {{ color:#9fb0c3; font:600 12.5px ui-sans-serif,system-ui,-apple-system,sans-serif;
            margin-left:10px; letter-spacing:.2px; }}
  pre {{ margin:0; padding:16px 18px; background:#12161c; color:#d5dde6;
         font:13px/1.55 ui-monospace,SFMono-Regular,Menlo,Consolas,monospace;
         white-space:pre; }}
  .pass {{ color:#4ec97a; font-weight:600; }}
  .fail {{ color:#ff6b6b; font-weight:700; }}
  .head {{ color:#7aa7ff; font-weight:700; }}
  .err  {{ color:#ff8f6b; font-weight:600; }}
  .prompt {{ color:#4ec97a; font-weight:700; }}
  .cmd  {{ color:#ffd479; }}
  .summary {{ color:#ffffff; font-weight:700; }}
  .plus {{ color:#4ec97a; }}
  .minus {{ color:#ff6b6b; }}
  .tilde {{ color:#febc2e; }}
</style>
<div class="win">
  <div class="bar">
    <span class="dot r"></span><span class="dot y"></span><span class="dot g"></span>
    <span class="title">{html.escape(title)}</span>
  </div>
<pre>{body}</pre>
</div>
"""
    with open(out, "w") as fh:
        fh.write(page)
    print(f"wrote {out} ({len(text.splitlines())} lines)")


if __name__ == "__main__":
    render(sys.argv[1], sys.argv[2], sys.argv[3])
