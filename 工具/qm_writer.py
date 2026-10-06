#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""qm_writer.py -- 纯 Python 的 Qt .qm 翻译文件生成器（零第三方依赖）。

生成的 .qm 文件兼容 Qt 4.8 ~ Qt 6.x 的 QTranslator 加载器，
即 Proteus 8.x（Qt 4.8）与 Proteus 9.x（Qt 6）均可用。

文件结构（与经典 Proteus 8 汉化包一致，经实测可被 Proteus 8.16 加载）：

    magic (16 字节)
    [0x42] Hashes   : N x (u32 elfHash, u32 消息偏移)，按 hash 升序排列
    [0x69] Messages : 逐条消息记录，字节编码：
                       03 u32 长度 + 译文(UTF-16BE)
                       08 u32 长度 + 注释(UTF-8，通常为空)
                       06 u32 长度 + 原文(UTF-8)
                       07 u32 长度 + 上下文(UTF-8)
                       01 结束
    不写 Contexts 预过滤节（历史汉化包同样省略，加载器按可选处理）。

用法（命令行）：
    python qm_writer.py entries.json out.qm
    entries.json 格式: [{"context":..., "source":..., "comment":..., "translation":...}, ...]
"""

import json
import struct
import sys

MAGIC = bytes([0x3c, 0xb8, 0x64, 0x18, 0xca, 0xef, 0x9c, 0x95,
               0xcd, 0x21, 0x1c, 0xbf, 0x60, 0xa1, 0xbd, 0xdd])

TAG_HASHES = 0x42
TAG_MESSAGES = 0x69


def elf_hash(data: bytes) -> int:
    """Qt QTranslator 使用的 elfHash（结果为 0 时取 1）。"""
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


def build(entries, out_path, stats=None):
    """将词条列表编译为 .qm 文件。

    entries: 可迭代对象，每项为 dict：
        context / source / translation / comment(可选)
    返回写入的消息条数。
    """
    messages = bytearray()
    pairs = []
    seen = set()
    count = 0

    for e in entries:
        ctx = (e.get('context') or '')
        src = (e.get('source') or '')
        cmt = (e.get('comment') or '')
        tr = (e.get('translation') or '')
        if not src or not tr:
            continue
        key = (ctx, src, cmt)
        if key in seen:
            continue
        seen.add(key)

        off = len(messages)
        t16 = tr.encode('utf-16-be')
        cb = cmt.encode('utf-8')
        sb = src.encode('utf-8')
        xb = ctx.encode('utf-8')

        messages += b'\x03' + struct.pack('>I', len(t16)) + t16
        messages += b'\x08' + struct.pack('>I', len(cb)) + cb
        messages += b'\x06' + struct.pack('>I', len(sb)) + sb
        messages += b'\x07' + struct.pack('>I', len(xb)) + xb
        messages += b'\x01'

        pairs.append((elf_hash(sb + cb), off))
        count += 1

    pairs.sort(key=lambda p: (p[0], p[1]))
    hashes = bytearray()
    for h, off in pairs:
        hashes += struct.pack('>II', h, off)

    out = bytearray(MAGIC)
    out += bytes([TAG_HASHES]) + struct.pack('>I', len(hashes)) + hashes
    out += bytes([TAG_MESSAGES]) + struct.pack('>I', len(messages)) + messages

    with open(out_path, 'wb') as f:
        f.write(out)

    if stats is not None:
        stats['messages'] = count
        stats['bytes'] = len(out)
    return count


def main():
    if len(sys.argv) < 3:
        print(__doc__)
        return 1
    with open(sys.argv[1], encoding='utf-8') as f:
        entries = json.load(f)
    stats = {}
    n = build(entries, sys.argv[2], stats)
    print('written %d messages, %d bytes -> %s' % (n, stats.get('bytes', 0), sys.argv[2]))
    return 0


if __name__ == '__main__':
    sys.exit(main())
