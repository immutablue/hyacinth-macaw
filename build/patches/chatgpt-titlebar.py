#!/usr/bin/env python3
# hyacinth-macaw - Personal custom build of Immutablue
# Copyright (C) 2026  Zach Podbielniak
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

"""Move the ChatGPT desktop app's window controls back under the window manager.

Same problem, same shape of fix as claude-desktop-titlebar.py.  The Electron
main bundle picks window options per "appearance", and both of the branches
that a normal chat window can land on ask for a frameless window with a
Chromium window-controls overlay on Linux:

    case`quickChat`:case`primary`: ... n===`win32`||n===`linux`
        ? {titleBarStyle:`hidden`,titleBarOverlay:M9(r), ...}
    case`detached`: return {titleBarStyle:`hidden`,titleBarOverlay: ...}

A frameless window is never decorated by mutter, so `org.gnome.desktop.wm
.preferences button-layout` is ignored and the minimise/maximise/close
buttons are always drawn by the app on the right hand side.  The overlay
windows (dictation, avatar, hotkey windows) get their `frame:!1` from a
separate helper and are deliberately left alone -- those are meant to be
chromeless.

Neither the app nor its launcher exposes a setting for this, so the fix is to
edit the bundled `app.asar`: capitalising the two option keys leaves them as
unknown BrowserWindow options, which Electron ignores, and the windows fall
back to the default `frame: true`.  GTK then draws the frame and honours the
user's button layout.

Dropping the option is not enough on its own.  Two call sites reach for
`BrowserWindow.setTitleBarOverlay()` afterwards, gated on the *platform and
the window appearance* rather than on whether the window actually has an
overlay:

    installApplicationMenuTitleBarOverlaySync(e,t){
        if(process.platform!==`win32`&&process.platform!==`linux`
           ||t!==`primary`&&t!==`quickChat`&&t!==`detached`)return;
        let n=()=>{e.isDestroyed()||e.setTitleBarOverlay(M9(...))};
        ...
    }
    setWindowZoom(e,t){ ... (process.platform===`win32`||process.platform
        ===`linux`)&&(this.windowZooms.set(n.id,t),n.setTitleBarOverlay(...))}

`setTitleBarOverlay()` throws `TypeError: Titlebar overlay is not enabled` on
a window that is not frameless, and the first of those runs synchronously
from `createWindow()` during `createPrimaryWindow()`.  The throw unwinds into
the bootstrap's `catch`, which destroys every window and quits -- the app
looks like it never starts.  So the same edit also has to take those two
branches off the Linux path: comparing against `Linux` instead of `linux`
never matches `process.platform`, which turns the first into an early return
and the second into a no-op, exactly as on a platform without overlays.

Every replacement is the same byte length as the original -- only the case of
existing characters changes -- so every entry offset in the asar header stays
valid.  The SHA-256 digests of each patched entry are recomputed and written
back into the header, because the embedded asar integrity fuse is enabled on
this build.  The header is re-serialised from the parsed tree rather than
patched as text -- an entry spans a single integrity block, so its block
digest and its whole-file digest are the same hex string and a search-and-
replace could not tell them apart.  Electron writes the header as compact
JSON, so the round trip is verified to be byte for byte identical before
anything is rewritten, and hex digests are fixed width, so the header keeps
its size.  The archive is nearly 300 MB, so the edits are seeked to and
written individually rather than rewriting the whole file.

Usage:
    chatgpt-titlebar.py <path-to-app.asar>

Exits 0 when the archive was patched or was already patched, and non-zero
when any expected pattern could not be found (typically because a ChatGPT
update reshaped the window options).
"""

import hashlib
import json
import os
import re
import struct
import sys

# Minified string quoting is not stable across releases, so every anchor
# matches whichever quote character is in use and echoes it back untouched.
# The backreference keeps each pair matched, so a quote inside a value cannot
# widen the match.
QUOTE = rb'(["\'`])'


def rule(unpatched, patched, replacement, minimum):
    """Bundle one edit: what to find, what "already done" looks like, the fix."""
    return {
        'unpatched': re.compile(unpatched),
        'patched': re.compile(patched),
        'replacement': replacement,
        'minimum': minimum,
    }


RULES = [
    # The per-appearance window options themselves.  Capitalised, both keys
    # become unknown BrowserWindow options and the window keeps `frame: true`.
    # Current builds emit two of these (primary/quickChat, and detached).
    rule(
        rb'titleBarStyle:' + QUOTE + rb'hidden\1,titleBarOverlay:',
        rb'TitleBarStyle:' + QUOTE + rb'hidden\1,TitleBarOverlay:',
        lambda m: b'TitleBarStyle:' + m.group(1) + b'hidden' + m.group(1) + b',TitleBarOverlay:',
        2,
    ),

    # installApplicationMenuTitleBarOverlaySync()'s platform guard.  Never
    # matching `Linux` makes the whole condition true on Linux, so the
    # function returns before installing the nativeTheme hook that calls
    # setTitleBarOverlay() -- which would otherwise throw during startup.
    rule(
        rb'process\.platform!==' + QUOTE + rb'win32\1&&process\.platform!==' + QUOTE + rb'linux\2\|\|t!==' + QUOTE + rb'primary\3',
        rb'process\.platform!==' + QUOTE + rb'win32\1&&process\.platform!==' + QUOTE + rb'Linux\2\|\|t!==' + QUOTE + rb'primary\3',
        lambda m: (b'process.platform!==' + m.group(1) + b'win32' + m.group(1)
                   + b'&&process.platform!==' + m.group(2) + b'Linux' + m.group(2)
                   + b'||t!==' + m.group(3) + b'primary' + m.group(3)),
        1,
    ),

    # setWindowZoom()'s platform guard, which re-applies the overlay geometry
    # whenever the renderer changes zoom.  Same throw, same fix.
    rule(
        rb'process\.platform===' + QUOTE + rb'win32\1\|\|process\.platform===' + QUOTE + rb'linux\2\)&&\(this\.windowZooms\.set\(',
        rb'process\.platform===' + QUOTE + rb'win32\1\|\|process\.platform===' + QUOTE + rb'Linux\2\)&&\(this\.windowZooms\.set\(',
        lambda m: (b'process.platform===' + m.group(1) + b'win32' + m.group(1)
                   + b'||process.platform===' + m.group(2) + b'Linux' + m.group(2)
                   + b')&&(this.windowZooms.set('),
        1,
    ),
]


def walk(node, prefix):
    """Yield (path, entry) for every file entry in an asar header tree."""
    for name, entry in node['files'].items():
        if 'files' in entry:
            yield from walk(entry, prefix + '/' + name)
        else:
            yield prefix + '/' + name, entry


def refresh_integrity(data, entry, name, base):
    """Recompute entry's integrity digests in place over the patched bytes."""
    integrity = entry.get('integrity')
    if integrity is None:
        print('chatgpt: patched %s (entry carries no integrity block)' % name)
        return

    offset = int(entry['offset'])
    size = int(entry['size'])
    blob = bytes(data[base + offset:base + offset + size])

    integrity['hash'] = hashlib.sha256(blob).hexdigest()

    block_size = int(integrity['blockSize'])
    integrity['blocks'] = [
        hashlib.sha256(blob[index * block_size:(index + 1) * block_size]).hexdigest()
        for index in range(len(integrity['blocks']))
    ]

    print('chatgpt: patched %s and refreshed its integrity digests' % name)


def dump_header(header):
    """Serialise an asar header the way Electron's JSON.stringify does."""
    return json.dumps(header, separators=(',', ':'), ensure_ascii=False).encode()


def collect_edits(data):
    """Apply every rule to data in place; return (edits, ok).

    Each rule must either match at least its expected number of times or be
    fully applied already.  A rule that matches neither means the bundle has
    been reshaped, and a half-applied set of rules is what crashes the app --
    so anything short of "all found" or "all already done" is a failure.
    """
    edits = []
    ok = True

    for entry in RULES:
        hits = list(entry['unpatched'].finditer(data))
        already = len(entry['patched'].findall(data))

        if not hits:
            # Re-running the build over an already patched image is a no-op.
            if already >= entry['minimum']:
                print('chatgpt: %d site(s) already patched' % already)
            else:
                print('chatgpt: expected pattern not found (%s)'
                      % entry['unpatched'].pattern.decode('ascii', 'replace'))
                ok = False
            continue

        if len(hits) < entry['minimum']:
            print('chatgpt: expected at least %d match(es), found %d (%s)'
                  % (entry['minimum'], len(hits),
                     entry['unpatched'].pattern.decode('ascii', 'replace')))
            ok = False
            continue

        # Only the case of existing characters changes, so each edit stays
        # byte for byte the same length and no entry offset moves.
        for hit in hits:
            replacement = entry['replacement'](hit)
            if len(replacement) != hit.end() - hit.start():
                print('chatgpt: replacement would resize the archive, refusing to write')
                return [], False
            edits.append((hit.start(), replacement))
            data[hit.start():hit.start() + len(replacement)] = replacement

    return edits, ok


def main(argv):
    if len(argv) != 2:
        print('usage: chatgpt-titlebar.py <path-to-app.asar>')
        return 2

    path = argv[1]

    # readinto a preallocated buffer: the archive is ~300 MB and read() would
    # briefly hold two copies of it.
    data = bytearray(os.path.getsize(path))
    with open(path, 'rb') as handle:
        handle.readinto(data)

    edits, ok = collect_edits(data)
    if not ok:
        return 1
    if not edits:
        return 0

    # asar layout: a pickled header (size at [4:8], JSON length at [12:16],
    # JSON starting at 16) followed by the concatenated file contents.
    header_size = struct.unpack('<I', data[4:8])[0]
    json_len = struct.unpack('<I', data[12:16])[0]
    header_raw = bytes(data[16:16 + json_len])
    header = json.loads(header_raw)
    base = 8 + header_size

    # Everything below rewrites the header from the parsed tree, so bail out
    # now if this build's header is not the compact JSON that produces.
    if dump_header(header) != header_raw:
        print('chatgpt: header does not round trip, refusing to write')
        return 1

    # Find the archive entries the patched bytes belong to so their integrity
    # digests can be refreshed.  In practice every hit lives in the same main
    # bundle, but nothing guarantees that across releases.
    pending = {offset for offset, _ in edits}
    for name, entry in walk(header, ''):
        if not pending:
            break
        if 'offset' not in entry:
            continue

        offset = int(entry['offset'])
        size = int(entry['size'])
        covered = {t for t in pending if offset <= t - base < offset + size}
        if not covered:
            continue

        pending -= covered
        refresh_integrity(data, entry, name, base)

    if pending:
        print('chatgpt: %d patch offset(s) fall outside any asar entry' % len(pending))
        return 1

    header_raw = dump_header(header)
    if len(header_raw) != json_len:
        print('chatgpt: header length changed, refusing to write')
        return 1

    # Only the edited spans and the header move, so seek to them instead of
    # rewriting the whole archive.
    with open(path, 'r+b') as handle:
        for offset, replacement in edits:
            handle.seek(offset)
            handle.write(replacement)
        handle.seek(16)
        handle.write(header_raw)

    print('chatgpt: patched %d site(s)' % len(edits))
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv))
