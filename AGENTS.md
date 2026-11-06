# 冰雪拼音开发约定

## 通用约定

始终用中文回复。方案名称优先用全称，其次用简称，再次用完整 `schema_id`；不使用无 `snow_` 前缀的名称，引用代码或命令参数除外。

| 全称 | 简称 | schema_id |
| --- | --- | --- |
| 冰雪四拼 | 四拼 | `snow_sipin` |
| 冰雪三拼 | 三拼 | `snow_sanpin` |
| 冰雪一拼 | 一拼 | `snow_yipin` |
| 冰雪键道 | 键道 | `snow_jiandao` |
| 冰雪清韵 | 清韵 | `snow_qingyun` |

Markdown 每个段落、列表项各写一行，不按行宽硬换行；只在段落、列表项、标题、表格行、代码块之间换行。列表项的第二段空一行并缩进；代码块和 YAML 注释不受此限。

中文叙述统一使用直角引号「」，嵌套引用使用『』。代码语法的引号、输入方案实际输出的标点及其说明保留原字符。

## 目录与部署

外部方案子模块统一在 `deps/`：雾凇拼音为 `rime-ice`，英文词库为 `rime-easy-en`，部件全拼为 `rime-radical-pinyin`。首次克隆或更新依赖后运行 `git submodule update --init deps/rime-radical-pinyin`。

部件反查与笔画反查共用入口：冰雪四拼、冰雪三拼、冰雪键道用 `u` 和 `stroke` 标签；冰雪清韵用反引号和 `pinyin` 标签，并共用拼音反查；`lookup_pinyin` 显示读音。冰雪一拼不接入部件反查。

`radical_pinyin.schema.yaml`、`radical_pinyin.dict.yaml` 由子模块提供：本机软链指向原文件，发布、测试和 iCloud 同步时复制到方案目录根目录。不要手改或提交根目录副本。

```sh
bun scripts/link.ts link      # 幂等建立软链；新增文件后重跑，冲突确认后加 --force
bun scripts/link.ts unlink    # 还原成独立副本
bun scripts/link.ts sync      # 手动单向镜像到 iCloud，并重新打包
```

- `~/.local/share/fcitx5/rime` 的 `snow_*.schema.yaml`、`snow_*.dict.yaml`、`snow_*.fixed.txt` 和 `lua/snow` 是本仓库软链，修改后只需重新部署，**不需要同步**；修改 Lua 后部署会重建状态并重新 `require`，无需重启输入法。
- iOS 元书方案位于 iCloud 的 `RimeUserData/rime-snow-pinyin`。iCloud 不跟随软链，`sync` 仅复制有变化的文件并清理已删除项；需要在 iOS 使用改动时手动运行。它还用系统 `zip` 替换 `~/Library/Mobile Documents/iCloud~com~ihsiao~apps~Hamster3/Documents/sync/rime-snow-pinyin.zip`，保留相对路径。Android 元书通过应用导入方案。
- `.gitignore` 排除的 `*.custom.yaml`、`*.userdb`、`build/`、`user.yaml`、`installation.yaml` 各自独立，在仓库跑 mira 不会污染实际词频。

## 开发脚本

在仓库根目录运行命令，依赖用 `bun install --cwd scripts` 安装。脚本通过 `scripts/lib/paths.ts` 定位资源；显式传入的相对路径按调用目录解析。`generate-*` 生成数据，`export-*` 导出已有数据；公共逻辑、源数据、皮肤、实验工具分别在 `scripts/lib/`、`scripts/data/`、`scripts/skin/`、`scripts/experiments/`。

```sh
bun run --cwd scripts format          # 格式化 TypeScript 和 JSON
bun run --cwd scripts check:format    # 检查格式
```

下表脚本用 `bun scripts/<脚本名>` 运行；`data/`、`lib/` 相对 `scripts/`，`output/` 为仓库根目录下被 Git 忽略的输出目录。

| 脚本与参数 | 输入与用途 | 默认输出 |
| --- | --- | --- |
| `generate-pinyin-dict.ts [输出文件]` | `data/tygf-pinyin.tsv` 与 `lib/character-pinyin.ts` 中固定版本的在线大字集拼音 | `snow_pinyin.dict.yaml` |
| `check-pinyin-dict.ts` | 离线检查单字词典全部读音在五个方案中的完整音节编码，异常时退出失败 | 不写文件 |
| `generate-word-dicts.ts [base ext tencent] [--output-dir 目录]` | 雾凇子模块 `deps/rime-ice/cn_dicts/` 与当前单字词典；省略词库名时生成三份 | `snow_pinyin.*.dict.yaml`；未确定读音写入 `diff/` |
| `generate-english-dict.ts [输入文件] [输出文件]` | 默认读取 `deps/rime-easy-en/easy_en.dict.yaml` | `snow_yingpin.dict.yaml` |
| `generate-stroke-dict.ts <输入文件> [输出文件]` | 外部三列笔画 TSV，格式见「笔画与地区字形」 | `snow_bihua.dict.yaml` |
| `generate-radical-codes.ts [输出目录]` | `data/radicals.tsv` 与冰雪四拼、冰雪三拼的拼写规则 | `lua/snow/radical_sipin.txt`、`radical_sanpin.txt` |
| `annotate-words.ts <词表> [输出文件]` | 每行一个词，可带后续 TSV 列；优先查现有词典，缺词时调用注音库 | `output/annotated-words.tsv` |
| `export-user-dict.ts <用户词典快照> [输出文件]` | 读取 Rime 文本快照，按使用次数排序 | `output/user-dict.tsv`（词、编码、次数三列） |
| `export-character-codes.ts [输出文件]` | 冰雪四拼单字评测码表，需联网下载大字集拼音 | `output/character-codes.tsv` |
| `export-word-codes.ts [输出目录]` | 离线模拟冰雪四拼动态码长，导出评测与大竹查询码表 | `output/word-codes/` 下的 `simulated.txt`、`dazhu.txt` |
| `generate-yipin-tests.ts [输出文件]` | 从 `data/yipin-syllables.tsv` 每组固定取首条生成音节测试 | `output/yipin-tests.yaml.snippet`；审阅后合入 spec，不覆盖功能测试 |

词典和辅助码生成默认更新仓库产物，审阅时指定临时路径，例如 `bun scripts/generate-word-dicts.ts base --output-dir /tmp/snow-word-dicts`；诊断文件随输出写入 `diff/`。注音逻辑在 `lib/word-pinyin.ts`，按需初始化且不写文件；`data/word-pinyin-overrides.tsv` 修正词语读音，`data/complete-pinyin-overrides.tsv` 修正 pinyin-pro 完整词库。

### 皮肤

`bun scripts/generate-skins.ts [输出目录] [--backend hamster|trime|all] [--trime-toolbar-width 按键总宽度dp]` 生成七组皮肤，默认 `all`，输出到调用目录的 `output/skins/{hamster,trime}/`。单后端直接写入指定目录；显式选 `--backend hamster` 且不传目录时，写入 iOS 元书的 `~/Library/Mobile Documents/iCloud~com~ihsiao~apps~Hamster3/Documents/Skins/`。Android 或审阅产物应显式指定目录，如 `/tmp/snow-skins`。

布局、配色、共用类型分别在 `scripts/skin/{layouts,palette,types}.ts`；元书和同文后端为 `hamster.ts`、`trime.ts`：

- 元书输出 iOS、Android 共用皮肤目录、亮暗预览 `demo.png` 和 `.cskin`；图标用 `{ ios, android }` 映射，打包依赖系统 `zip`。`.cskin` 内必须只有一个与皮肤同名的根目录。
- 同文每组输出一份 `.trime.yaml`，复用内置 `trime.yaml` 样式、安卓键表和新版工具栏。工具栏依次为菜单、常用语、剪贴板、编辑、中文、ABC、收起；菜单靠左，其余靠右。默认七键各 50 dp、总宽 350 dp；`--trime-toolbar-width 315` 对应各 45 dp。
- `.github/workflows/release.yml` 分别打包 `snow-pinyin-skins-hamster.zip`（目录与 `.cskin`）和 `snow-pinyin-skins-trime.zip`（主题文件）。

### 实验工具

`scripts/experiments/` 需自行提供外部语料，不参与发布；输入约定见各脚本：`generate-sanpin-shortcuts.ts <词频表> [输出文件]` 生成冰雪三拼简词候选，默认 `output/sanpin-shortcuts.tsv`；`frequency/derive-character-frequency.ts <语料目录> [输出文件]` 推导单字剩余词频；`frequency/resegment-word-frequency.ts <语料目录> <玲珑词表> [输出文件]` 重新分词。

## 版本与发布

版本唯一来源是 `lua/snow/snow.lua` 的 `snow.version`，不要手改 YAML 版本号。生成词典也从 `scripts/version.ts` 读取版本；词典头不支持 Rime `__include`。

```sh
bun scripts/version.ts 0.3.12   # 更新 snow.lua 和全部 snow_*.schema.yaml、snow_*.dict.yaml
bun scripts/version.ts          # 查看版本
bun scripts/version.ts --check  # 检查全部 YAML 版本；可再传入发布标签核对
```

每次发布都必须主动检查并更新文档网站 `/Users/tansongchen/Public/input`，无需用户另行提醒：

- 按功能、默认配置、快捷键、词库和皮肤变更更新教程、公共片段、导航与示例；输入统计放各方案的 `advanced.md`。暂不扩写实验性的冰雪英拼和冰雪注音；面向用户只介绍 `snow-pinyin.zip` 和皮肤包，预览包只用于网页演示。
- 安装、皮肤、补丁文件入口、备份等通用说明集中到 `index.md`；方案逻辑（后置、调频、固定候选、词库、辅助码和笔画来源）、专用文件及按键说明放对应教程，共用内容通过 `components/` 引用。避免增加顶层页面，不维护统一的 `shortcuts.md`。
- 行为或示例变更后，用当前版本独立部署环境重建候选框模拟缓存，并核对网页预览包版本。文档仓库必须通过格式检查、网站构建及改动页面的链接、公共引用、候选显示、交互输入检查，才算更新完成。
- 开发脚本、统计设计和维护约定留在本仓库，网站按需链接，不复制实现细节。发布必须通过功能、词典和性能门禁，并核对标签与全部版本号一致。

## 笔画与地区字形

笔画反查及冰雪四拼、冰雪三拼的笔画辅助码共用生成的 `snow_bihua.dict.yaml`，不要手改；冰雪键道、冰雪一拼的部件辅助码和冰雪清韵形码不使用此表。

在方案的 `*.custom.yaml` 选择字形来源，重新部署即可，无需重建词典：

```yaml
patch:
  translator/shape_sources: [G, T]
```

- 标签区分大小写，多个取并集；省略或 `null` 默认 `[G]`，`[]` 只保留无标签记录，无标签记录始终可用。全部标签为 `[G, H, T, J, K, N, V, M, S, B, U]`。
- 仅影响可用笔顺与辅助码提示，不影响普通拼音候选；原表未收录的字不做辅助码过滤。独立笔画方案也支持此配置。
- 原表为三列 TSV：单字、空格分隔的 `1`～`5` 笔画、逗号分隔的标签（可空）；横竖撇点折对应 `12345`。生成器校验记录、合并同字同笔顺标签，跳过并报告空笔画，输出如 `令\t34154HNTV`。
- 更新原表后运行 `bun scripts/generate-stroke-dict.ts /path/to/strokes.tsv [输出文件]`（默认 `snow_bihua.dict.yaml`），再跑 `bun scripts/test.ts`。
- 棱镜先用 `xform/[A-Z]+$//` 去标签，再映射按键；查询、排序、补全交给原生 table translator。`bihua.lua` 通过 `ReverseLookup("snow_bihua")` 读取完整编码，按候选词典语言名识别笔画候选，须在反查过滤器前筛选来源并修正补全提示，避免误筛共用段标签的冰雪清韵拼音候选。

## 测试

功能测试在 `spec/*.test.yaml`，由 mira 运行。日常入口先并行跑五方案功能测试（约 40 秒），通过后串行测性能；失败只打印失败用例，完整日志见输出中的临时目录。

```sh
bun scripts/test.ts                  # 全部五方案
bun scripts/test.ts yipin qingyun    # 指定方案，snow_ 前缀可省
bun scripts/check-pinyin-dict.ts     # 修改词典或拼写运算后离线检查音节编码
```

### 音节校验与测试环境

`generate-pinyin-dict.ts` 写入前校验输入读音；`test.ts`、CI 和发布流程离线检查现有词典的五方案完整音节编码。`scripts/lib/pinyin-validation.ts` 依据 `../input` 的教程定义规则：四拼为声码＋1～2 韵码＋调码，三拼为声韵调，键道为声韵，清韵为声码＋九键韵码，一拼为声介＋可省韵基＋四声标记。检查展开实际拼写规则与引用，保留完整音节的 `derive` 分支，跳过 `abbrev`、简码、顶功及字母伪音节；异常应修正来源或运算，不得放宽正则。

`test.ts` 的以下隔离措施不得省略：

- 精简源目录：只复制 `git ls-files -co --exclude-standard` 文件，排除本机词频等私有文件，避免 mira 每次复制整个仓库。
- 每方案的 `default.custom.yaml` 只启用被测方案，避免部署全部方案。
- 每个 mira 独立 `TMPDIR`：它启动时会删除固定的 `$TMPDIR/mira`，共享目录会互相破坏。
- 每方案独立编译缓存：先复制 `build/`，结束后写回更新文件；带 patch 的部署（冰雪三拼、冰雪键道的 `sentence`，冰雪四拼的 `special`）会改写方案缓存，词典重建也会竞争。直接在仓库跑 mira、`rime_api_console` 时必须串行。

单部署可用 mira `-R`；它直接用仓库作源目录，先清测试词频，且不能与其他 mira 并行：

```sh
rm -rf *.userdb
mira -C build -R '^popping$' spec/snow_sipin.test.yaml
```

### 用例约束

- 断言只可用 `cand`（元素含 `.text`、`.comment`）、`preedit`、`commit`；`assert` 被包进 `return (...)`，只能写表达式。临时探查可用 `error(...)`；未加引号的值中，空格后的 `#` 会成为 YAML 注释，改用 `tostring(#cand)` 等写法。
- `has()` 扫全部候选；断言首页时用 `page()`（`page_size` 为 6）。固定词每类只测一例，整表校验直接比对 `snow_*.fixed.txt`，不照搬教程清单。
- **造词断言 `cand[1]`，不要断言 `commit`**：末尾两个空格会把缓冲内容上屏，无法据此判断是否入库。
- 同一 `deploy` 的各 `send` 共享用户词典。原始词频断言放 `popping` 且排在上屏用例之前；动态码长、自动造词、缓冲造词等写词典用例放独立部署（`encoding` / `buffered` / `schema_userdb`）。例如上屏「冰雪」后，它会迁到短码，原码首选随之变化。

### 按键反馈延迟

`bun scripts/benchmark-latency.ts [方案]` 用带 librime-lua 的 `rime_api_console` 测量，默认每场景 30 轮；依赖 Bun、`scripts/` 依赖及已初始化的部件子模块。控制台从 PATH 查找，可用 `--console` 指定。用例在 `scripts/data/latency-cases.ts`，覆盖查词、反查、补码、翻页、退格、顶屏、缓冲造词和连续输入；冰雪一拼发送完整按下／松开事件，首轮校验首页候选或上屏结果。

```sh
bun scripts/benchmark-latency.ts --ci  # 五方案全部场景，至少 200 轮，统一预算
bun scripts/benchmark-latency.ts jiandao --case '^dense-prefix$' --rounds 200 --max-p99-ms 50
bun scripts/check-latency.ts output/latency/report.json  # 复查已保存报告
```

方案参数可省 `snow_` 前缀；`--case` 为场景正则；`--output-dir` 默认调用目录的 `output/latency/`，同名文件覆盖；`--ref` 测历史版本，源码和子模块按该引用取，驱动与用例仍用当前代码。`test.ts` 始终测性能，旧 `--latency` 参数仅作兼容。

- **环境与口径**：冻结源码，五方案串行，各场景独立临时目录、编译副本和空用户词典，不用本机补丁或缓存；同场景各轮共享学习结果。不能与 mira、其他基准或网站构建并行。常驻控制台每次只发一键，计时到完整候选页和只读 `print schema list` 屏障返回，包含 IPC、候选惰性生成、控制台序列化和解析，不含界面、硬件、部署、断言与落盘；另测 100 次空请求作参考，不扣除开销。
- **采样**：首轮 `first` 与后续 `repeat` 分开，首轮不等于清空系统页缓存后的冷启动。分位数用 nearest rank；30 轮时每位置 29 个重复样本，发布至少 200 轮时每位置至少 199 个。
- **统一预算**：`scripts/lib/latency-budget.ts` 的 `LATENCY_BUDGET` 要求有效反馈 P50 < 10 ms、P95 < 25 ms、P99 < 50 ms；各场景及按键位置 P99 < 50 ms，首次最大反馈 < 100 ms。顺序方案计全部事件，一拼计并击末次松开和非并击操作。不得按方案放宽、删除离群值、重跑择优，或用低耗时按下／松开事件稀释分布。
- **输出与 CI**：仅写输出目录的 `samples.jsonl`、`report.json` 和控制台日志，不回写文档。按方案、场景、位置、按键类型、首轮／重复轮统计分位数、最大值和超过 16/50/100 ms 的次数。超时、部署或控制台失败、按键处理或 Lua 错误、首轮结果不符、预算超限均失败，超限前先保存报告。`.github/workflows/latency.yml` 固定运行环境，在 Actions 摘要展示指标和失败项，缺报告时提示查看日志，并上传原始构件；push、PR、发布共用，`release.yml` 必须通过 `needs: [functional, latency]` 依赖功能与性能门禁成功。

## Lua 开发

适用于 `lua/snow/` 自写组件；`calculator.lua` 的外来函数库不强求。

### 结构与语法

- 文件顺序：头注释（`-- xxx处理器`＋一句说明）→ 按需 `local snow = require "snow.snow"` → `---@class XxxEnv: Env` → 组件表 → `return`，各部分空行分隔。`statistics.lua` 头注释另含用户用法和各量说明。
- 组件表用 `processor` / `segmentor` / `translator` / `filter`，不用 `this`、`select`；多组件分别命名并 `return { a = a, ... }`。translator 也用表＋`init` / `func`；配置在 `init` 读入 `env`，空 `init` / `fini` 省略。
- `env` 类型用本模块名＋`Env`（如 `ShapeFilterEnv`），所有 `---@param env` 引用本模块类，无扩展字段则用 `Env`；不借用其他模块的类。局部变量和字段用 snake_case。
- 参数固定为 processor `(key_event, env)`、translator `(input, segment, env)`、filter `(translation, env)` 和 `tags_match(segment, env)`。
- 不定义全局变量／函数；辅助函数用 `local function`，外部需要的挂组件表。所有方案共用 Lua 状态；动态求值用专用环境表 `load(chunk, name, "t", env)`，不写 `_G`。
- 2 空格缩进，无 tab、行尾分号和多余条件括号；`require "x"` 不加括号。字符串默认双引号，含 `"` 时才用单引号；字符串操作用 `input:sub(...)` 等方法调用。
- 只有 `nil`、`false` 为假；空字符串、0、空表均为真。分别用 `s == ""`、`#list == 0`、`next(map) == nil` 判空，`not value` 仅判断真假或缺值。`a and b or c` 仅在 `b` 不为 `false` / `nil` 时可作条件表达式，否则写 `if`。

### 生命周期

- filter 必须用 `tags_match` 限定段（通常 `abc`，反查再加 `pinyin`）；按开关／配置生效的 `unicode`、`special` 也在这里判断。
- `notifier:connect` 结果存入 `env`，`fini` 必须 `disconnect()`，避免跨方案累积回调。
- `fini` 调用 `snow.release_db` 释放词典，将 `Memory`、`ReverseLookup`、`Component.*` 等 C++ 对象置 `nil` 后 `collectgarbage()`；普通 Lua 表无需手动清空。

### lua 的三处坑

- **代理码查询必须走 `snow.prepare`，不要自行 yield**：`table_like.lua` 补入的空格、`?`、`~` 会虚增 quality，`snow.prepare` 同时修正 quality 和 `_end`。
- **`fini` 不可读 `env.engine.schema`**：切换时它已指向新方案。`snow.get_db` / `release_db` 按方案名引用计数，须在 `init` 把名字存入 `env`，`fini` 使用保存值；否则旧库 `LOCK` 无法释放，同步报 `already held by process`。
- **`LevelDb(name)` 会被 Rime 当用户词典同步**：键须为 `编码 \t词`（编码后有空格，恰好一个 `\t`），值须为 `c=… d=… t=…`；错误格式会被丢弃或归零。合并取同键 `c` 的最大值，跨设备计数应含 installation_id 且只增不减，见 `statistics.lua`。

### 输入统计

修改前先读 [docs/statistics.md](docs/statistics.md)，修改后按其「验证方法」检查两个不变式；spec 不含统计用例。

- 新写的直接上屏一律调用 `snow.commit_text`；`engine:commit_text` 不触发 `commit_notifier`，会漏记字数并把按键带入下一次上屏。
- 顶屏、略码等「触发键属于下一词」的上屏，须在上屏前设 `snow.handover`，上屏后恢复 `nil`。非缓冲 popping 的 `confirm_current_selection()` 即上屏，必须在 confirm 前设置。

### 类型检查

自写 Lua 须无 lua-language-server 的 strict 警告，含 `no-unknown`。VS Code 只检查打开过的文件，全量检查用：

```sh
echo '{"diagnostics.groupFileStatus":{"strict":"Any","strong":"Any"},"diagnostics.disable":["lowercase-global"]}' > "$TMPDIR/luarc.json"
~/.vscode/extensions/sumneko.lua-*/server/bin/lua-language-server --check="$PWD" \
  --configpath="$TMPDIR/luarc.json" --checklevel=Warning --logpath="$TMPDIR/luals" --check_format=json
```

末行给总数，详情在 `$TMPDIR/luals/check.json`。常见类型陷阱：

- `snow.get_db` 锁冲突时可返回 `nil`，持有字段标 `LevelDb|nil`，使用前判空。
- 0 起始索引表标 `table<integer, string>`，不用 `string[]`；索引须为 integer，数字字符用 `s:byte(i) - 48`，不要用返回 `number?` 的 `tonumber()`。
- 动态字符串键表用 `---@type table<string, string>` 标注，含字面量表及先建空表再填充的情况。
- 分支分别赋字面量和 `x:sub(...)` 可能触发 LuaLS 的 `no-unknown`，加注解也无效；改成 `x = cond and "" or x:sub(1, -2)`。

## 方案专用约束

### 简拼棱镜

冰雪键道和冰雪三拼共用 `snow_jiandao_jianpin`，两者英数字母的声母必须一致：辅音为该字母，元音为 `x`，三拼只在键道字母码后补轻声 `a`。不可让棱镜同时兼容两套声母，否则三拼 `dlxm` 会把自造「哆啦A梦」顶到「多线」前。修改字母规则时保持一致或拆棱镜，并同步修改棱镜 algebra 和 `snow_sanpin.fixed.txt` 的「字母」段。

### 冰雪一拼的功能并击

功能并击最多三键，不新增四键并击。`jkl`、`uio`、`m,.` 分别输入 `itj`、`itjf`、`itjh`；`jio` 与 `Control+j` 均切换缓冲，再次操作关闭。不提供 Unicode 码点输入，候选 Unicode 注释仍可用 `Control+u` 切换。

## 组件顺序

五方案共用以下相对顺序，缺席组件及替代项见注释；不要仅按多数方案的现状判断顺序。

### processors 顺序

```yaml
  processors:
    - lua_processor@*snow.statistics*processor
    - ascii_composer
    - chord_composer                        # 仅冰雪一拼
    - lua_processor@*snow.shape_processor    # 冰雪清韵无
    - lua_processor@*snow.abbreviation      # 仅冰雪四拼
    - lua_processor@*snow.select_character  # 冰雪一拼无
    - lua_processor@*snow.popping           # 冰雪一拼用 combo_popping
    - recognizer
    - lua_processor@*snow.user_dict         # 冰雪一拼无
    - key_binder
    - lua_processor@*snow.editor            # 仅冰雪四拼、冰雪清韵
    - speller
    - punctuator
    - selector
    - navigator
    - express_editor
```

`popping` 通过前置守卫（非 release / alt / ctrl / caps，当前段带 `abc`）后，必定 `env.engine:process_key()` 从链顶重投并返回 `kAccepted`。处理器需要的键命中本方案 `speller/popping` 的 `accept` 时，通常须放在 popping 前；否则默认放后。若故意靠大写转小写重投触发，则必须放后。

| 必须满足 | 原因 |
| --- | --- |
| `statistics` 第一 | 看到被其他组件吃掉的每个键；除并击末次松开外返回 `kNoop`，按 `ascii_mode` 跳过全局／临时西文，靠 `snow.redispatching` 去重 |
| `shape_processor` < `popping`、`key_binder` | 辅助码键可触发顶屏；四拼 `1` 还被绑为定位；一拼完整音节后任何小写字母都会顶屏 |
| `abbreviation` < `popping` | 大写略码不能先被转成小写 |
| `select_character` < `popping` | `[`、`]` 命中标点大写顶 |
| `popping` < `recognizer` | 键道无前缀 `jianpin` 会匹配普通编码并 `PushInput`，放前会让 3 码以上顶功静默失效 |
| `popping` < `editor` | 清韵靠大写元音的 `strategy: append` 转小写重投补码，放前会让小写元音直接补码 |
| `user_dict` < `key_binder` | `Control+bracketleft` 绑定 Escape；上移／下移分支落空也须返回 `kAccepted`，防止清空整句 |

其余沿用 Rime 原生顺序。拿不准时跑 mira；疑似失效的小写功能须连大写一起测。改 processors 必须跑 `bun scripts/test.ts` 全部五份 spec。

手工逐键探查用 `~/Public/librime` build 的 `rime_console -i`（带 librime-lua）：将仓库 rsync 到临时目录，补 `default.yaml` 和仅含待测方案的 `default.custom.yaml`；每行一键，特殊键用 `{bracketleft}`、`{Control+bracketleft}`，输出 `comp. : [{abc,jianpin}dejx=>得奖]` 可查看段标签。

### segmentors / translators / filters 顺序

```yaml
  segmentors:
    - ascii_segmentor
    - matcher
    - abc_segmentor
    - affix_segmentor@stroke              # 冰雪一拼、冰雪清韵无
    - affix_segmentor@pinyin              # 冰雪一拼无
    - affix_segmentor@jianpin             # 仅冰雪键道
    - punct_segmentor
    - fallback_segmentor

  translators:
    - punct_translator
    - <主翻译器>                           # script_translator；冰雪三拼用 *snow.table_like*t12
    - <方案专属副翻译器>                    # 冰雪键道、冰雪清韵的 script_translator@<方案>、
                                          # 冰雪三拼的 *snow.table_like*jianpin
    - table_translator@stroke             # 冰雪一拼无
    - table_translator@radical            # 冰雪一拼无；与笔画共用反查入口
    - script_translator@pinyin            # 冰雪一拼无
    - lua_translator@*snow.buffered       # 仅冰雪四拼、冰雪三拼、冰雪键道
    - lua_translator@*snow.datetime       # 冰雪一拼无
    - lua_translator@*snow.statistics*translator
    - lua_translator@*snow.number         # 冰雪一拼无
    - lua_translator@*snow.unicode*translator # 冰雪一拼无
    - lua_translator@*snow.calculator     # 以下冰雪一拼均无
    - history_translator

  filters:
    - lua_filter@*snow.placeholder        # 冰雪一拼无
    - lua_filter@*snow.bihua              # 冰雪一拼无；按词典语言名筛选笔画，须在反查过滤器之前
    - lua_filter@*snow.enforce            # 仅冰雪键道
    - reverse_lookup_filter@lookup_pinyin # 冰雪一拼无
    - reverse_lookup_filter@lookup_<方案>  # 冰雪一拼、冰雪清韵无
    - lua_filter@*snow.fix
    - lua_filter@*snow.shape_filter       # 冰雪清韵用 *snow.qingyun 占这个位置
    - lua_filter@*snow.postpone           # 冰雪一拼无
    - uniquifier                          # 冰雪清韵无
    - simplifier                          # 冰雪清韵无
    - lua_filter@*snow.hint               # 冰雪四拼用 *snow.special；冰雪一拼、冰雪清韵无
    - lua_filter@*snow.unicode*filter
```

改 preedit 的 filter 必须在 `uniquifier` 前：`UniquifiedCandidate::preedit()` 恒返回首个被合并候选的 preedit，包装器上的修改会丢失；`comment` 不受影响。

### 一致性自查

修改任一组件段落后运行，四段结果应均为 0；它只检测跨方案前后顺序冲突，不检查缺席组件。

```sh
python3 - <<'PY'
import re, itertools
S = ["snow_sipin", "snow_sanpin", "snow_yipin", "snow_jiandao", "snow_qingyun"]
for sec in ("processors", "segmentors", "translators", "filters"):
    L = {}
    for s in S:
        m = re.search(r"(?m)^  %s:\n((?:    - .*\n)+)" % sec, open(s + ".schema.yaml").read())
        L[s] = [l.strip()[2:] for l in m.group(1).rstrip("\n").split("\n")]
    allc = sorted({c for v in L.values() for c in v})
    bad = [(a, b) for a, b in itertools.combinations(allc, 2)
           if any(a in v and b in v and v.index(a) < v.index(b) for v in L.values())
           and any(a in v and b in v and v.index(b) < v.index(a) for v in L.values())]
    print(sec, len(bad), bad)
PY
```
