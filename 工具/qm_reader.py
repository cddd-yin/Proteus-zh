#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Proteus QM toolkit - reader.

Parses Qt .qm translation files. The layout is the same across Qt 4.8 .. Qt 6.x
for the sections Proteus uses (verified against qtranslator.cpp sources of
Qt 4.8.7 and Qt 6.7), so this reader works for both the legacy 8.x packs and
modern packs.

Usage:
  python qm_reader.py <file.qm> info
  python qm_reader.py <file.qm> json <out.json>
"""

import sys
import json
import struct

try:
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')
    sys.stderr.reconfigure(encoding='utf-8', errors='replace')
except Exception:
    pass

MAGIC = bytes([0x3c, 0xb8, 0x64, 0x18, 0xca, 0xef, 0x9c, 0x95,
               0xcd, 0x21, 0x1c, 0xbf, 0x60, 0xa1, 0xbd, 0xdd])

TAG_CONTEXTS = 0x2f
TAG_HASHES = 0x42
TAG_MESSAGES = 0x69
TAG_NUMERUS = 0x88
TAG_DEPENDENCIES = 0x96
TAG_LANGUAGE = 0xa7

# message-record tags
T_END = 1
T_SOURCE16 = 2
T_TRANSLATION = 3
T_CONTEXT16 = 4
T_OBSOLETE1 = 5
T_SOURCE = 6
T_CONTEXT = 7
T_COMMENT = 8


def elf_hash(data: bytes) -> int:
    """elfHash as used by QTranslator (h=1 when result would be 0)."""
    h = 0
    for b in data:
        h = ((h << 4) + b) & 0xFFFFFFFF
        g = h & 0xF0000000
        if g:
            h ^= g >> 24
        h &= (~g & 0xFFFFFFFF)
    if h == 0:
        h = 1
    return h


class QmFile:
    def __init__(self, path):
        with open(path, 'rb') as f:
            data = f.read()
        if data[:16] != MAGIC:
            raise ValueError('bad magic: %s' % path)
        self.path = path
        self.data = data
        pos = 16
        self.sections = {}
        while pos + 5 <= len(data):
            tag = data[pos]
            blen = struct.unpack_from('>I', data, pos + 1)[0]
            pos += 5
            if tag == 0 or blen == 0 or pos + blen > len(data):
                break
            self.sections[tag] = data[pos:pos + blen]
            pos += blen

        self.messages_pool = self.sections.get(TAG_MESSAGES, b'')
        self.hashes = []
        self.contexts = []
        self.htable_size = 0
        self.bucket_offsets = []
        self.context_pool = b''
        self._parse_contexts()
        self._parse_hashes()

    # ---------- sections ----------

    def _parse_contexts(self):
        c = self.sections.get(TAG_CONTEXTS)
        if not c:
            return
        hsz = struct.unpack_from('>H', c, 0)[0]
        self.htable_size = hsz
        self.bucket_offsets = [
            struct.unpack_from('>H', c, 2 + 2 * i)[0] for i in range(hsz)
        ]
        pool = c[2 + 2 * hsz:]
        self.context_pool = pool
        names = []
        for off in self.bucket_offsets:
            if off == 0:
                continue
            p = off * 2
            while p < len(pool):
                ln = pool[p]
                p += 1
                if ln == 0:
                    break
                names.append(pool[p:p + ln].decode('utf-8', 'replace'))
                p += ln
        self.contexts = names

    def _parse_hashes(self):
        h = self.sections.get(TAG_HASHES)
        if not h:
            return
        n = len(h) // 8
        self.hashes = [struct.unpack_from('>II', h, 8 * i) for i in range(n)]

    # ---------- message records ----------

    def parse_message_at(self, off):
        m = self.messages_pool
        p = off
        rec = {'source': None, 'context': None, 'comment': None, 'translations': []}
        while p < len(m):
            tag = m[p]
            p += 1
            if tag == T_END:
                break
            if tag in (T_TRANSLATION, T_SOURCE16, T_SOURCE, T_CONTEXT16, T_CONTEXT, T_COMMENT):
                ln = struct.unpack_from('>I', m, p)[0]
                p += 4
                blob = m[p:p + ln]
                p += ln
                if tag == T_TRANSLATION:
                    rec['translations'].append(blob.decode('utf-16-be', 'replace'))
                elif tag == T_SOURCE:
                    rec['source'] = blob.decode('utf-8', 'replace')
                elif tag == T_SOURCE16:
                    rec['source'] = blob.decode('utf-16-be', 'replace')
                elif tag == T_CONTEXT:
                    rec['context'] = blob.decode('utf-8', 'replace')
                elif tag == T_CONTEXT16:
                    rec['context'] = blob.decode('utf-16-be', 'replace')
                elif tag == T_COMMENT:
                    rec['comment'] = blob.decode('utf-8', 'replace')
            elif tag == T_OBSOLETE1:
                p += 4
            else:
                break
        return rec

    def entries(self, dedupe=True):
        seen = set()
        out = []
        for h, off in self.hashes:
            rec = self.parse_message_at(off)
            key = (rec['context'], rec['source'], rec['comment'] or '')
            if dedupe and key in seen:
                continue
            seen.add(key)
            out.append({
                'context': rec['context'],
                'source': rec['source'],
                'comment': rec['comment'] or '',
                'translation': rec['translations'][0] if rec['translations'] else '',
                'hash': h,
            })
        return out


def main():
    path = sys.argv[1]
    mode = sys.argv[2] if len(sys.argv) > 2 else 'info'
    q = QmFile(path)
    if mode == 'info':
        print('file:', path)
        print('sections:', ', '.join('%s(%d B)' % (hex(k), len(v)) for k, v in sorted(q.sections.items())))
        print('hTableSize:', q.htable_size, 'contexts in buckets:', len(q.contexts))
        print('hash entries:', len(q.hashes))
        ents = q.entries()
        print('deduped entries:', len(ents))
        ctx_count = {}
        for e in ents:
            ctx_count[e['context']] = ctx_count.get(e['context'], 0) + 1
        print('top contexts by count:')
        for ctx, n in sorted(ctx_count.items(), key=lambda x: -x[1])[:25]:
            print('   %5d  %s' % (n, ctx))
        print('--- sample entries ---')
        for e in ents[:20]:
            src = (e['source'] or '')[:55]
            tr = (e['translation'] or '')[:55]
            print('  [%s]  %r -> %r' % ((e['context'] or '')[:34], src, tr))
    elif mode == 'json':
        out = sys.argv[3]
        ents = q.entries()
        with open(out, 'w', encoding='utf-8') as f:
            json.dump(ents, f, ensure_ascii=False, indent=1)
        print('dumped %d entries to %s' % (len(ents), out))
    else:
        raise SystemExit('unknown mode: %s' % mode)


if __name__ == '__main__':
    main()
