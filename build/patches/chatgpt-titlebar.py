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

The option keys survive minification but the string quoting does not, so the
anchor matches whichever quote character is in use and echoes it back
untouched.

The replacement is the same byte length as the original, so every entry
offset in the asar header stays valid.  The SHA-256 digests of each patched
entry are recomputed and written back into the header in case the embedded
asar integrity fuse is enabled.  The header is re-serialised from the parsed
tree rather than patched as text -- the entry spans a single integrity block,
so its block digest and its whole-file digest are the same hex string and a
search-and-replace could not tell them apart.  Electron writes the header as
compact JSON, so the round trip is verified to be byte for byte identical
before anything is rewritten, and hex digests are fixed width, so the header
keeps its size.  The archive is nearly 300 MB, so the edits are seeked to and
written individually rather than rewriting the whole file.

Usage:
    chatgpt-titlebar.py <path-to-app.asar>

Exits 0 when the archive was patched or was already patched, and non-zero
when the expected pattern could not be found (typically because a ChatGPT
update reshaped the window options).
"""

import hashlib
import json
import os
import re
import struct
import sys

# The minified window options are stable across releases even though the
# surrounding identifiers and the string quoting are not, so anchor on the two
# option keys and let the minifier pick whichever quote character it likes.
# The backreference keeps the pair matched, so a quote inside the value cannot
# widen the match.
UNPATCHED = re.compile(rb'titleBarStyle:(["\'`])hidden\1,titleBarOverlay:')
PATCHED = re.compile(rb'TitleBarStyle:(["\'`])hidden\1,TitleBarOverlay:')


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

    hits = list(UNPATCHED.finditer(data))
    already = len(PATCHED.findall(data))

    # Re-running the build over an already patched image must be a no-op.
    if not hits:
        if already:
            print('chatgpt: %d window(s) already patched' % already)
            return 0
        print('chatgpt: no frameless window options found, nothing to patch')
        return 1

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

    # Echo the original quote character back so each edit stays byte for byte
    # the same length; only the two leading key characters change case.
    edits = []
    for hit in hits:
        quote = hit.group(1)
        replacement = b'TitleBarStyle:' + quote + b'hidden' + quote + b',TitleBarOverlay:'
        if len(replacement) != hit.end() - hit.start():
            print('chatgpt: replacement would resize the archive, refusing to write')
            return 1
        edits.append((hit.start(), replacement))
        data[hit.start():hit.start() + len(replacement)] = replacement

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

    print('chatgpt: patched %d window definition(s)' % len(edits))
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv))
