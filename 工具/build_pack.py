#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""build_pack.py -- Proteus 汉化包构建器。

流程：合并词库（2014 风标包 + picdupe 包 + 本项目修正）-> 质量过滤 -> 编译 proteus_zh_CN.qm

用法：
    python build_pack.py                    # 使用脚本内置默认路径
    python build_pack.py --dict-dir 词库 --out 成品/proteus_zh_CN.qm

依赖：仅标准库 + 同目录的 qm_writer.py（纯 Python 编译，无需 Qt 工具链）。
"""

import argparse
import io
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)  # 项目根目录（Proteus汉化/）

sys.path.insert(0, HERE)
from qm_writer import build as build_qm  # noqa: E402

try:
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')
except Exception:
    pass

# ---------------------------------------------------------------- 质量过滤

# 这些短词条保留（大小写敏感）
SHORT_KEEP = {'OK', 'I/O', 'BOM', 'SMT'}
# 英文虚词（小写比较）
STOPWORDS = {'for', 'and', 'by', 'the', 'of', 'to', 'is', 'it', 'at', 'in',
             'no', 'ok', 'off', 'on', 'up', 'not', 'are', 'as', 'or'}

_RE_CODE = re.compile(r'^[A-Z0-9][A-Z0-9/:\-]{1,4}$')


def is_noise(source):
    """判断是否为“缩写噪声”或高风险短词条（机翻污染重灾区）。"""
    s = source.strip()
    if not s:
        return True
    if s in SHORT_KEEP:
        return False
    if len(s) <= 2:
        return True                      # 单/双字符：X、0D、16、M1、mm ...
    if len(s) <= 3 and s.lower() in STOPWORDS:
        return True                      # for/and/by/no ...
    if _RE_CODE.match(s) and s not in SHORT_KEEP:
        return True                      # 2~5 位全大写代号：BOT、DRL、RIP、SDF ...
    return False


# 已知错误翻译修正（优先于一切来源）
BAD_FIXES = [
    {'contexts': ['ARES_Stackup', 'StackupLayers'], 'source': 'plane', 'translation': '平面层'},
    {'contexts': ['DrillTable'], 'source': 'Pad', 'translation': '焊盘'},
]

# ---------------------------------------------------------------- 构建

def load_json(path, default=None):
    if not os.path.exists(path):
        return default
    with open(path, encoding='utf-8') as f:
        return json.load(f)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--dict-dir', default=os.path.join(ROOT, '词库'))
    ap.add_argument('--out', default=os.path.join(ROOT, '成品', 'proteus_zh_CN.qm'))
    ap.add_argument('--report', default=os.path.join(ROOT, '构建缓存', '构建报告.txt'))
    args = ap.parse_args()

    pic = load_json(os.path.join(args.dict_dir, 'dict_picdupe.json'), [])
    d14 = load_json(os.path.join(args.dict_dir, 'dict_2014.json'), [])
    overrides = load_json(os.path.join(args.dict_dir, 'overrides.json'), [])

    merged = {}
    dropped = []
    conflicts = []

    def put(e, tag, do_filter=True):
        ctx = e.get('context') or ''
        src = e.get('source') or ''
        tr = e.get('translation') or ''
        cmt = e.get('comment') or ''
        if not src or not tr:
            return
        if do_filter and is_noise(src):
            dropped.append((tag, ctx, src, tr))
            return
        if src.strip() == tr.strip():
            return
        key = (ctx, src, cmt)
        if key in merged and merged[key]['translation'] != tr:
            conflicts.append((key, merged[key]['translation'], tr, tag))
        merged[key] = {'context': ctx, 'source': src, 'comment': cmt,
                       'translation': tr, 'from': tag}

    for e in pic:
        put(e, 'picdupe')
    for e in d14:
        put(e, '2014')          # 2014 覆盖 picdupe
    for f in BAD_FIXES:
        put(f, 'ours', do_filter=False)
    for o in overrides:
        ctxs = o.get('contexts') or [o.get('context') or '']
        for c in ctxs:
            put({'context': c, 'source': o['source'], 'translation': o['translation']}, 'ours', do_filter=False)

    os.makedirs(os.path.dirname(args.out), exist_ok=True)
    os.makedirs(os.path.dirname(args.report), exist_ok=True)

    stats = {}
    n = build_qm(merged.values(), args.out, stats)

    # 报告
    r = io.StringIO()
    r.write('=== Proteus 汉化包构建报告 ===\n')
    r.write('来源：picdupe %d 条 / 2014 %d 条 / 修正 %d 条\n' % (len(pic), len(d14), len(BAD_FIXES)))
    r.write('过滤丢弃（缩写噪声）: %d 条\n' % len(dropped))
    r.write('合并后写入: %d 条（编译去重后 %d）\n' % (len(merged), n))
    r.write('冲突(新旧译文不同，取 2014): %d 条\n' % len(conflicts))
    r.write('输出: %s (%d 字节)\n' % (args.out, stats.get('bytes', 0)))
    r.write('\n丢弃样例（前 40 条）:\n')
    for tag, ctx, src, tr in dropped[:40]:
        r.write('  [%s] %s | %r -> %r\n' % (tag, ctx[:38], src, tr))
    r.write('\n冲突样例（前 30 条）:\n')
    for (k, a, b, tag) in conflicts[:30]:
        r.write('  ctx=%s src=%r | 2014=%r vs picdupe=%r\n' % (k[0][:34], k[1], a, b))
    with open(args.report, 'w', encoding='utf-8') as f:
        f.write(r.getvalue())

    print('OK: %d messages -> %s' % (n, args.out))
    print('dropped noise: %d; conflicts: %d' % (len(dropped), len(conflicts)))
    print('report: %s' % args.report)


if __name__ == '__main__':
    main()
