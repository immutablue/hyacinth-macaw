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

"""Move Claude Desktop's window controls back under the window manager.

Claude Desktop builds its main BrowserWindow with `titleBarStyle: "hidden"`
plus a Chromium window-controls overlay, so the window is frameless and
mutter never decorates it.  That means `org.gnome.desktop.wm.preferences
button-layout` is ignored and the minimise/maximise/close buttons are always
drawn by the app on the right hand side.

Neither the app nor its launcher exposes a setting for this, so the fix is to
edit the bundled `app.asar`: capitalising the two option keys leaves them as
unknown BrowserWindow options, which Electron ignores, and the window falls
back to the default `frame: true`.  GTK then draws the frame and honours the
user's button layout.

The option keys survive minification but the string quoting does not — the
1.30096 bundle switched from `"hidden"` to a backtick literal — so the anchor
matches whichever quote character is in use and echoes it back untouched.

The replacement is the same byte length as the original, so every entry
offset in the asar header stays valid.  Electron's embedded asar integrity
fuse is enabled on this build, so the SHA-256 digests of the patched entry
are recomputed and written back into the header — also in place, since hex
digests are fixed width and the header must not change size.

Usage:
    claude-desktop-titlebar.py <path-to-app.asar>

Exits 0 when the archive was patched or was already patched, and non-zero
when the expected pattern could not be found (typically because a Claude
Desktop update reshaped the window options).
"""

import hashlib
import json
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


def main(argv):
    if len(argv) != 2:
        print('usage: claude-desktop-titlebar.py <path-to-app.asar>')
        return 2

    path = argv[1]
    data = bytearray(open(path, 'rb').read())

    # Re-running the build over an already patched image must be a no-op.
    if len(PATCHED.findall(data)) == 1:
        print('claude-desktop: main window already patched')
        return 0

    hits = list(UNPATCHED.finditer(data))
    if len(hits) != 1:
        print('claude-desktop: expected exactly 1 titlebar match, found %d' % len(hits))
        return 1

    # asar layout: a pickled header (size at [4:8], JSON length at [12:16],
    # JSON starting at 16) followed by the concatenated file contents.
    header_size = struct.unpack('<I', data[4:8])[0]
    json_len = struct.unpack('<I', data[12:16])[0]
    header_raw = bytes(data[16:16 + json_len])
    header = json.loads(header_raw)
    base = 8 + header_size

    # Echo the original quote character back so the edit stays byte for byte
    # the same length; only the two leading key characters change case.
    quote = hits[0].group(1)
    replacement = b'TitleBarStyle:' + quote + b'hidden' + quote + b',TitleBarOverlay:'
    target = hits[0].start()

    if len(replacement) != hits[0].end() - target:
        print('claude-desktop: replacement would resize the archive, refusing to write')
        return 1

    data[target:target + len(replacement)] = replacement

    # Find the archive entry the patched bytes belong to so its integrity
    # digests can be refreshed.
    for name, entry in walk(header, ''):
        if 'offset' not in entry:
            continue

        offset = int(entry['offset'])
        size = int(entry['size'])
        if not offset <= target - base < offset + size:
            continue

        integrity = entry.get('integrity')
        if integrity is None:
            print('claude-desktop: patched %s (entry carries no integrity block)' % name)
            break

        blob = bytes(data[base + offset:base + offset + size])
        new_header = header_raw

        # Whole-file digest.  Replace the hex string in the raw header rather
        # than re-serialising the JSON, so key order and spacing are untouched.
        old_hash = integrity['hash'].encode()
        new_hash = hashlib.sha256(blob).hexdigest().encode()
        if new_header.count(old_hash) != 1:
            print('claude-desktop: file digest %s is not unique in the header' % integrity['hash'])
            return 1
        new_header = new_header.replace(old_hash, new_hash)

        # Per-block digests; only the block containing the patch changes.
        block_size = int(integrity['blockSize'])
        for index, old_block in enumerate(integrity['blocks']):
            chunk = blob[index * block_size:(index + 1) * block_size]
            new_block = hashlib.sha256(chunk).hexdigest()
            if new_block == old_block:
                continue
            if new_header.count(old_block.encode()) != 1:
                print('claude-desktop: block digest %s is not unique in the header' % old_block)
                return 1
            new_header = new_header.replace(old_block.encode(), new_block.encode())

        if len(new_header) != len(header_raw):
            print('claude-desktop: header length changed, refusing to write')
            return 1

        data[16:16 + json_len] = new_header
        print('claude-desktop: patched %s and refreshed its integrity digests' % name)
        break
    else:
        print('claude-desktop: patch offset does not fall inside any asar entry')
        return 1

    open(path, 'wb').write(bytes(data))
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv))
