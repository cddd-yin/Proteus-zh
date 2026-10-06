# 词库说明

三个 JSON 词库，供 `工具/build_pack.py` 合并编译。

字段：`context`（翻译上下文）/ `source`（英文原文）/ `translation`（中文译文）/
`comment`（消歧注释，可有）/ `hash`（原包哈希，参考用）/ `from`（来源标记，构建时写入）。

| 文件 | 来源 | 许可 |
| --- | --- | --- |
| `dict_2014.json` | 2014 年「风标电子」Proteus 汉化包（网络流传的 `proteus_zh_CN.qm`）解析而来 | 原作者不详，仅供学习交流；如涉权利问题请联系删除 |
| `dict_picdupe.json` | [picdupe/Proteus-Chinese](https://github.com/picdupe/Proteus-Chinese) 发布包解析而来 | MIT（全文见 `第三方许可-Picdupe-MIT.txt`） |
| `overrides.json` | 本项目补充/修正（最高优先级） | MIT |

## 重建

```powershell
python 工具\build_pack.py
# 输出: 成品\proteus_zh_CN.qm 与 构建缓存\构建报告.txt
```

构建规则：先过滤缩写噪声，再合并；优先级 `overrides > dict_2014 > dict_picdupe`；
同一 `(context, source)` 冲突时保留 2014 译文（8.x 风格更贴合传统界面）。

## 贡献

- 修正某条翻译：在 `overrides.json` 中追加 `{"contexts": ["上下文"], "source": "英文", "translation": "中文"}`
- 新增词条：同上（`contexts` 可列多个候选上下文，未命中的条目运行时自动闲置、无副作用）
- 修改后重新构建并提 PR 即可，欢迎附截图
