# Proteus 汉化（Proteus-zh）

高质量、可维护的 **Proteus 界面汉化语言包**与**纯 Python 工具链**。
基于 Proteus 官方多语言（Qt 语言包）机制实现：只投放翻译文件，**不改动任何程序二进制**，可一键还原。

![主页](截图/03-本汉化包-主页.png)

---

## 怎么装？（新手照做即可）

> 全程只需三步，**不用装 Python、不用改软件**。装完重启 Proteus 就是中文。

### 第 1 步：把这个仓库下载到电脑

在页面右上角点绿色的 **`Code`** 按钮 → 选 **`Download ZIP`** → 下载后**解压**到任意文件夹（例如桌面）。
解压后应能看到 `一键安装汉化.bat`、`工具`、`成品` 等文件。

> 提示：如果不会解压，右键压缩包 → 用系统自带的「全部解压缩」即可。

### 第 2 步：双击 `一键安装汉化.bat`

- 会弹出「是否允许此应用对你的设备进行更改？」→ 点 **是**（写入安装目录需要管理员权限，脚本会自动请求）。
- 脚本会自动找到 Proteus 安装目录并安装汉化包，看到 `[√] 汉化已安装` 即成功。
- 若自动找不到 Proteus 目录，脚本会提示你**把 Proteus 安装目录路径粘贴进去**（一般形如
  `C:\Program Files (x86)\Labcenter Electronics\Proteus 8 Professional`）。

### 第 3 步：重启 Proteus

关闭 Proteus 再打开，界面即为中文。

> **想还原英文**：双击 `一键还原英文.bat`，重启 Proteus。
> **不想用脚本**：见下方[「方式二：手动复制一个文件」](#方式二手动复制一个文件最简单)。

---

## 安装方式二：手动复制一个文件（最简单）

如果你只想下载**一个文件**、手动放一下：

1. 下载汉化文件：[`成品/proteus_zh_CN.qm`](成品/proteus_zh_CN.qm)（点进去后按 **Download / 下载原始文件** 按钮）
   直链：https://github.com/cddd-yin/Proteus-zh/raw/main/成品/proteus_zh_CN.qm
2. 把它复制到 **Proteus 安装目录的 `Translations` 文件夹**里，例如：

   ```
   C:\Program Files (x86)\Labcenter Electronics\Proteus 8 Professional\Translations\
   ```

   > 复制到 `Program Files` 下时，Windows 会弹「需要管理员权限」→ 点「继续」即可。
3. 重启 Proteus。

**还原英文**：把 `Translations\proteus_zh_CN.qm` 删掉，重启软件。

---

## 常见问题（FAQ）

**Q：双击 `一键安装汉化.bat` 一闪就没 / 提示找不到 Proteus？**
A：多半是没找到安装目录。请手动运行脚本并指定路径：

```powershell
powershell -ExecutionPolicy Bypass -File 工具\安装汉化.ps1 -InstallDir "C:\Program Files (x86)\Labcenter Electronics\Proteus 8 Professional"
```

把路径换成你自己的 Proteus 安装目录（该目录里应有 `Translations` 与 `BIN` 文件夹）。

**Q：Windows 提示「已保护你的电脑 / SmartScreen」不让运行？**
A：点 **「更多信息」→「仍要运行」**。脚本是纯文本、可自行打开查看，只做复制文件这一件事。

**Q：装完还是英文？**
A：① 确认已**完全关闭并重新打开** Proteus；② 确认文件确实在安装目录的 `Translations\` 里（文件名须为 `proteus_zh_CN.qm`）；③ Proteus 按**系统语言**自动选用中文包，若系统不是中文，请在软件内语言设置里选择中文。

**Q：怎么彻底卸载？**
A：双击 `一键还原英文.bat`（会恢复安装前的备份，或直接删掉汉化文件），重启 Proteus。

**Q：杀毒软件报毒？**
A：.bat / .ps1 只是复制文件，可能被误报。可右键用记事本打开查看内容，确认无误后放行。

---

## 特性

- **一份文件、多代通用**：`proteus_zh_CN.qm` 同时兼容 Proteus 8.x（Qt 4.8）与 9.x（Qt 6）——不同代的翻译上下文并存于同一文件，各版本自动命中自己的词条
- **16,000+ 条翻译**：合并三代来源——2014「风标」经典汉化包（8.x 风格词条）＋ [picdupe/Proteus-Chinese](https://github.com/picdupe/Proteus-Chinese)（MIT，9.x 风格词条）＋ 本项目补充修正
- **实测验证**：Proteus 8.16 SP3 真机验证（主页 + 原理图工程界面全中文，见 `截图/`）
- **零依赖工具链**：`工具/` 内为 Python 标准库实现（3.8+），含自研 QM 编译器 `qm_writer.py`，可随时从词库 JSON 重建
- **可回退**：安装自动备份原文件；`一键还原英文.bat` 一键回英文

## 原理（一句话版）

Proteus 启动时按系统语言（中文系统 → `zh_CN`）自动加载 `Translations\proteus_zh_CN.qm`；本项目提供的就是这份翻译文件。**没有该文件时，设置里也没有「中文」可选项**——软件内的「选择语言包 / 修复语言包」即「安装语言包」。详见 [`docs/原理与兼容性.md`](docs/原理与兼容性.md)。

## 适配范围

| 版本 | 状态 |
| --- | --- |
| Proteus 8.16 SP3 | ✅ 实机验证（本仓库开发环境） |
| 其它 8.x（老版本 ~ 8.17） | ✅ 同机制、同格式，直接可用（欢迎反馈） |
| Proteus 9.x | ✅ 同机制；词条按 9.x 上下文合并（源自 9.1 包），建议反馈使用情况 |

## 目录结构

```
一键安装汉化.bat   仓库根目录双击安装（自动提权，推荐）
一键还原英文.bat   一键还原英文
成品/         构建好的 proteus_zh_CN.qm（安装用）
工具/         安装/还原脚本 + 纯 Python 构建链
  qm_writer.py   QM 编译器（无第三方依赖）
  qm_reader.py   QM 解析器（词库提取/审计用）
  build_pack.py  词库合并 + 质量过滤 + 编译
词库/         三个词库 JSON（详见 词库/README.md）
截图/         英中对比与验收截图
docs/         原理、兼容性、开发与验证记录
```

## 自行重建词库

```powershell
python 工具\build_pack.py
# 输出: 成品\proteus_zh_CN.qm 与 构建缓存\构建报告.txt
```

修正翻译：编辑 `词库/overrides.json`（最高优先级）后重新构建即可。

## 词库来源与致谢

- **2014「风标电子」经典汉化包**（网络流传）：8.x 风格词条（`RST:`/`DLG:`/`CMD:`/`MENU:`/类名上下文），约 6,200 条
- **[picdupe/Proteus-Chinese](https://github.com/picdupe/Proteus-Chinese)**（MIT）：9.x 风格词条（Qt 类名上下文），约 11,000 条
- 本项目：补充词条、修正错误、过滤缩写类机翻噪声、构建工具链

详细说明与许可信息见 [`词库/README.md`](词库/README.md)。

## 免责声明

- 本仓库为第三方非官方汉化项目，与 Labcenter Electronics Ltd. 无任何关联
- 仅提供界面翻译文件与工具，**不提供 Proteus 软件本体、破解、激活或授权绕过内容**
- Proteus 是 Labcenter Electronics Ltd. 的商标；请通过[官方渠道](https://www.labcenter.com/)获取并使用正版软件
- 使用本项目产生的一切后果由使用者自行承担

## 已知限制

- 词条覆盖依赖 Proteus 内部翻译上下文；版本变更可能导致少量词条失效（欢迎提交反馈/修正）
- 运行时拼接的动态文本（如部分状态栏提示）无法通过语言包覆盖
- Proteus 大版本更新后，建议重新运行构建脚本对比新版本词条

---

维护：cddd-yin ・ 构建工具为纯 Python（标准库）・ 许可：MIT（工具与本项目补充词条）
