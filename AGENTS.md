# 冰雪拼音开发约定

始终用中文回复。

## 方案名称

| 全称 | 简称 | schema_id |
| --- | --- | --- |
| 冰雪四拼 | 四拼 | `snow_sipin` |
| 冰雪三拼 | 三拼 | `snow_sanpin` |
| 冰雪一拼 | 一拼 | `snow_yipin` |
| 冰雪键道 | 键道 | `snow_jiandao` |
| 冰雪清韵 | 清韵 | `snow_qingyun` |

对话和报告里称呼方案时，优先用全称（冰雪四拼），其次用简称（四拼），再次用完整的 schema_id（`snow_sipin`）。不要用不带 `snow_` 前缀的 `sipin` 之类，除非是在引用代码或命令参数。

## Markdown 写法

一个段落、一个列表项写成一行，不按最大行长度硬换行。中文段落中间的换行在渲染时会变成多余的空格，续行前的缩进也会带进排版。只在段落、列表项、标题、表格行、代码块之间换行；列表项里的第二段照常空一行并缩进。代码块和 yaml 注释不受这条约束。

## 开发脚本

依赖安装在 `scripts/`：`bun install --cwd scripts`。以下命令在仓库根目录运行；脚本通过 `lib/paths.ts` 定位仓库资源，显式传入的相对路径按调用目录解析。`generate-*` 生成数据，`export-*` 导出已有数据；公共逻辑、源数据、皮肤生成和实验工具分别放在 `scripts/lib/`、`scripts/data/`、`scripts/skin/`、`scripts/experiments/`。

```sh
bun run --cwd scripts format          # 格式化 TypeScript 和 JSON
bun run --cwd scripts check:format    # 检查格式
```

测试、版本号和本机安装命令见下文。下表中的脚本均位于 `scripts/`，用 `bun scripts/<脚本名>` 运行；`data/` 指 `scripts/data/`，`output/` 指仓库根目录下已被 Git 忽略的输出目录。

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

词典和辅助码生成默认更新仓库产物，审阅时可指定临时输出路径，如 `bun scripts/generate-word-dicts.ts base --output-dir /tmp/snow-word-dicts`；指定 `--output-dir` 后诊断文件也放在该目录的 `diff/`。注音逻辑集中在 `lib/word-pinyin.ts`，按需初始化且不写文件；`data/word-pinyin-overrides.tsv` 配置词语读音修正，`data/complete-pinyin-overrides.tsv` 修正 pinyin-pro 的完整词库。

### 皮肤

`bun scripts/generate-skins.ts [输出目录] [--backend hamster|trime|all] [--trime-toolbar-width 按键总宽度dp]` 生成七组皮肤，默认后端为 `all`，输出到调用目录的 `output/skins/hamster/` 和 `output/skins/trime/`。单后端输出直接放在指定目录；显式指定 `--backend hamster` 且省略输出目录时，会写入供 iOS 元书使用的 `~/Library/Mobile Documents/iCloud~com~ihsiao~apps~Hamster3/Documents/Skins/`。为 Android 生成皮肤或审阅产物时显式指定目录，例如 `bun scripts/generate-skins.ts /tmp/snow-skins`。

布局、配色和共用类型分别在 `skin/layouts.ts`、`skin/palette.ts`、`skin/types.ts`；元书输入法（iOS、Android）与同文（Android）后端分别在 `skin/hamster.ts`、`skin/trime.ts`。元书输入法输出两平台共用的皮肤目录、亮暗预览 `demo.png` 和 `.cskin`，系统图标通过 `{ ios, android }` 映射，打包依赖系统 `zip`；`.cskin` 内必须只有一个与皮肤同名的根目录。同文每组输出一份 `.trime.yaml`，复用内置 `trime.yaml` 样式和安卓键表，工具栏采用新版配置。

同文工具栏依次为菜单、常用语、剪贴板、编辑、中文、ABC、收起，默认七键各 50 dp、总宽 350 dp；菜单靠左，其余键靠右。窄屏或悬浮键盘用 `--trime-toolbar-width` 调整按键总宽度，例如 `315` 对应七键各 45 dp。CI 按输入法发布 `snow-pinyin-skins-hamster.zip`（皮肤目录及 `.cskin`）和 `snow-pinyin-skins-trime.zip`（主题文件），由 `.github/workflows/release.yml` 打包。

### 实验工具

`scripts/experiments/` 依赖自行提供的外部语料，不参与发布：`generate-sanpin-shortcuts.ts <词频表> [输出文件]` 生成冰雪三拼简词候选，默认写入 `output/sanpin-shortcuts.tsv`；`frequency/derive-character-frequency.ts <语料目录> [输出文件]` 推导单字剩余词频，`frequency/resegment-word-frequency.ts <语料目录> <玲珑词表> [输出文件]` 重新分词。具体输入文件约定见各脚本。

## 实际目录

外部 Rime 方案子模块统一放在 `deps/`：雾凇拼音为 `deps/rime-ice`，英文词库为 `deps/rime-easy-en`，部件全拼为 `deps/rime-radical-pinyin`。

部件全拼反查依赖子模块 `deps/rime-radical-pinyin`，首次克隆或更新依赖后运行 `git submodule update --init deps/rime-radical-pinyin`。发布、功能测试和性能测试会把其中的 `radical_pinyin.schema.yaml`、`radical_pinyin.dict.yaml` 复制到独立方案目录的根目录；不要手改或提交根目录里的副本。冰雪四拼、冰雪三拼和冰雪键道与笔画反查共用 `u` 和 `stroke` 标签，冰雪清韵与拼音、笔画反查共用反引号和 `pinyin` 标签；`lookup_pinyin` 为这些候选显示拼音。冰雪一拼不接入部件反查。

`~/.local/share/fcitx5/rime` 里的 `snow_*.schema.yaml`、`snow_*.dict.yaml`、`snow_*.fixed.txt`、`lua/snow` 都是指回本仓库的软链，**没有「同步」这一步**：改哪边都是改同一份文件，`git pull` 后重新部署即可。

`link.ts` 同样管理两个 `radical_pinyin.*.yaml` 文件：本机软链直接指向子模块文件，iCloud 同步和压缩包则把它们复制到方案目录根目录。

```sh
bun scripts/link.ts link      # 建立软链（幂等，仓库新增文件后重跑；冲突时中止，确认后加 --force）
bun scripts/link.ts unlink    # 还原成独立副本
```

本机供 iOS 元书输入法使用的方案目录是 iCloud 里的 `RimeUserData/rime-snow-pinyin`。iCloud 不跟随软链，所以那边只能复制：`bun scripts/link.ts sync` 把同样的文件单向镜像过去，只复制内容有变化的文件，并清理仓库里已删除的文件。这一步要手动跑，改完想在 iOS 上用时再跑一次。Android 元书通过应用的方案导入入口安装，不使用这条 iCloud 同步路径。

`sync` 还会用系统 `zip` 重新打包全部同步文件，保留相对路径并替换 `~/Library/Mobile Documents/iCloud~com~ihsiao~apps~Hamster3/Documents/sync/rime-snow-pinyin.zip`。

本机私有、已被 `.gitignore` 排除的 `*.custom.yaml`、`*.userdb`、`build/`、`user.yaml`、`installation.yaml` 仍各自独立，所以在仓库里跑 mira 不会污染实际词频。

改动 lua 后重新部署即可生效：部署会重建 Lua 状态，所有模块重新 `require`，不用重启输入法。

## 版本号

版本号只写在 `lua/snow/snow.lua` 的 `snow.version` 里，不要手改 yaml。改版本时运行

```sh
bun scripts/version.ts 0.3.12   # 改写 snow.lua 和所有 snow_*.schema.yaml、snow_*.dict.yaml
bun scripts/version.ts          # 查看当前版本
```

词典生成脚本（`generate-pinyin-dict.ts`、`generate-word-dicts.ts`、`generate-english-dict.ts`、`generate-stroke-dict.ts`）也从 `scripts/version.ts` 读取同一个版本号。Rime 的 `__include` 只在方案里生效，词典头不支持，所以没法靠 yaml 本身共用一份。

### 发布时自动更新文档

每次发布新版本，都必须自动检查并更新文档网站 `/Users/tansongchen/Public/input`，作为发布工作的必要步骤，不等待用户另行提醒。根据本次版本的功能、默认配置、快捷键、词库和皮肤变更，更新受影响的教程、公共片段、导航与示例；输入统计放在各方案的 `advanced.md` 中。实验性的冰雪英拼和冰雪注音暂不扩写；面向用户只介绍 `snow-pinyin.zip` 和皮肤包，预览包仅用于网站演示。

网站的安装、皮肤、补丁文件入口和数据备份等通用说明合并到起始页 `index.md`，避免新增过多顶层页面。涉及方案逻辑的配置（如首选后置、调频、固定候选、词库、辅助码和笔画来源）及各方案专用文件说明，放在对应方案的教程中；共用内容通过 `components/` 下的公共片段引用复用，不堆在首页。各方案的按键逻辑分别在本方案的教程中说明，不维护统一的 `shortcuts.md`。

方案行为或示例发生变化时，使用当前版本的独立部署环境重新生成候选框模拟缓存，并检查网页演示所用预览包的版本。文档仓库须运行格式检查和网站构建，并检查改动页面的链接、公共引用片段、候选显示与交互输入；全部验证完成后，才算完成本次版本的文档更新。开发脚本、统计设计和维护约定继续保留在本仓库，网站按需链接，不必复制实现细节。

## 笔画与地区字形

笔画反查和冰雪四拼、冰雪三拼的笔画辅助码共用 `snow_bihua.dict.yaml`，由外部三列笔画表生成，不要手改。冰雪键道、冰雪一拼的部件辅助码及冰雪清韵的形码不使用此表。

在所用方案的 `*.custom.yaml` 中选择字形来源，重新部署即可生效，无需重新生成词典：

```yaml
patch:
  translator/shape_sources: [G, T]
```

- 多个标签取并集，区分大小写；省略或设为 `null` 时默认 `[G]`，`[]` 只保留无标签记录，无标签记录始终可用。全部来源为 `[G, H, T, J, K, N, V, M, S, B, U]`。
- 配置只影响可用笔顺及辅助码提示，不影响普通拼音候选；原表未收录的字不做辅助码过滤。独立笔画方案也支持此配置。
- 更新原表后运行 `bun scripts/generate-stroke-dict.ts /path/to/strokes.tsv [输出文件]`（输出默认 `snow_bihua.dict.yaml`），再运行 `bun scripts/test.ts`。
- 输入以制表符分三列：单字、空格分隔的 `1`～`5` 笔画、逗号分隔的来源标签（可空）；横、竖、撇、点、折对应 `12345`。脚本校验记录，合并同字同笔顺的标签，跳过并报告空笔画记录。输出为「汉字 + 制表符 + 数字笔顺及连续标签」，如 `令\t34154HNTV`。
- 棱镜用 `xform/[A-Z]+$//` 去掉标签再映射按键，查询、排序、补全交给原生 table translator。`bihua.lua` 通过 `ReverseLookup("snow_bihua")` 读取完整编码，供反查和辅助码共用；filter 按候选的词典语言名识别笔画候选，须在反查过滤器之前筛选来源并修正补全提示，避免误筛冰雪清韵中共用段标签的拼音候选。

## 测试

按键反馈性能测量见 [docs/latency.md](docs/latency.md)：`bun scripts/benchmark-latency.ts [方案]` 使用 `rime_api_console` 逐键测量；`bun scripts/test.ts [方案]` 默认在功能测试通过后串行执行性能测试，无需 `--latency`。完整场景采样完成后自动更新文档中的当前结果，并在输出目录保存文档快照；分方案测量保留其他行的时间与环境，历史版本及部分场景探查不覆盖完整结果。性能测量不能与 mira 或其他基准并行运行。

`bun scripts/benchmark-latency.ts --ci` 执行五方案统一发布预算（`scripts/lib/latency-budget.ts` 中的 `LATENCY_BUDGET`）：P50 < 10 ms、P95 < 25 ms、P99 < 50 ms，至少 200 轮；每场景及按键位置的 P99 也须 < 50 ms，首次反馈最大值 < 100 ms。不得按方案放宽标准或用低耗时的并击按下、松开事件稀释反馈分布。CI 和发布共用 `.github/workflows/latency.yml`，发布必须依赖门禁成功。

测试位于 `spec/*.test.yaml`，由 [mira](https://github.com/rimeinn/mira) 运行。日常用 `scripts/test.ts`，功能测试五方案并行，约 40 秒，随后串行运行性能测量；功能失败时只打印失败用例，完整输出留在它给出的临时目录里：

```sh
bun scripts/test.ts                  # 全部五个方案
bun scripts/test.ts yipin qingyun    # 只跑指定方案，snow_ 前缀可省
```

`generate-pinyin-dict.ts` 在写文件前校验全部输入读音；`scripts/test.ts`、CI 和发布流程也会离线检查现有词典在全部五个方案中的完整音节编码。各方案的正则定义在 `scripts/lib/pinyin-validation.ts`，依据 `../input` 中对应的拼写教程：冰雪四拼为声码加一至二码韵母加调码，冰雪三拼为声韵调三码，冰雪键道为声韵两码，冰雪清韵为声码加九键韵码，冰雪一拼为声介加可省略的韵基加四声标记。检查展开实际方案的拼写规则及引用，保留完整音节的 `derive` 分支，不检查 `abbrev`、简码、顶功或其他输入规则；字母伪音节不属于汉字音节，予以跳过。更新词典或拼写运算后运行 `bun scripts/check-pinyin-dict.ts`；结构异常应修正来源或运算，不应为已有异常放宽正则。

`scripts/test.ts` 为每个方案准备一份独立环境，这几步都是为了提速或者能并行，不要省掉：

- **精简的源目录**：mira 的每个 deploy 都会把整个 `source_dir`（spec 里写的是 `..`，也就是整个仓库，带 `.git`、`node_modules`、`build`，约 1 GB）复制一遍。脚本只复制 `git ls-files -co --exclude-standard` 列出的文件，相当于 CI 的全新 checkout。本机的 `*.userdb`、`user.yaml` 自然被排除在外，不用再 `rm -rf *.userdb`。
- **`default.custom.yaml` 只留被测方案**：否则每个 deploy 都要检查 `schema_list` 里的全部五个方案。这两项加起来，每个 deploy 从约 4 秒降到约 1.4 秒。
- **独立的 `TMPDIR`**：mira 的工作目录写死为 `$TMPDIR/mira`，启动时整个删掉，两个 mira 同时跑会互相删目录然后崩溃。
- **独立的缓存副本**：mira 与 `rime_api_console` 的编译产物统一放在仓库的 `build/`。带 `patch` 的 deploy（冰雪三拼、冰雪键道的 `sentence`，冰雪四拼的 `special`）会把改过的方案编译进缓存，改了词典后几个进程还会同时重建同一份 `.bin`，所以并行 mira 的 `-C` 不能指向同一个目录。脚本先把 `build/` 复制给每个方案，跑完再把更新过的文件写回去；直接在仓库运行控制台和 mira 时也应串行。

只调一个 deploy 时直接用 mira 的 `-R` 更快，但这会用仓库本身作 `source_dir`，所以要自己清词频，同时也不能有别的 mira 在跑：

```sh
rm -rf *.userdb                   # 清掉上次运行累积的词频，与 CI 的全新 checkout 对齐
mira -C build -R '^popping$' spec/snow_sipin.test.yaml
```

- 断言里只有 `cand`（元素含 `.text`、`.comment`）、`preedit`、`commit`；`assert` 会被包进 `return (...)`，只能写表达式。
- `has()` 扫描全部候选（可达上百个），文档说「出现在首页」时用 `page()`（`page_size` 为 6）。
- **造词类用例断言 `cand[1]`，不要断言 `commit`。** 用例末尾的两个空格会把缓冲区上屏，`commit` 恒等于想造的词，不管词有没有进用户词典。
- 固定词（`snow_*.fixed.txt`）**每一类只测一例**，不要把方案文档里的清单逐条搬进测试；要验整份词表就直接比对 fixed.txt。
- 临时探查状态可写 `assert: error(...)`，消息会打进 stderr。`assert` 的值不加引号，空格后的 `#` 会被当成注释，要写成 `tostring(#cand)` 之类。

### 按部署隔离会改变状态的用例

同一个 `deploy` 内各 `send` 共享用户词典。动态码长会让上屏过的词迁到更短的编码上，并从原编码的首选消失（`bxouivrf` 上屏「冰雪」后，`bxoui` 的首选就不再是「冰雪」）。因此：

- 依赖原始词频的断言放在 `popping` 部署，排在所有上屏类用例之前；
- 动态码长、自动造词、缓冲造词等写用户词典的用例放进独立部署（`encoding` / `buffered` / `schema_userdb`）。

## 简拼棱镜

冰雪键道和冰雪三拼共用 `snow_jiandao_jianpin` 按纯声母查多字词，前提是两边**英数字母的声母一致**（辅音字母是该字母，元音字母都是 `x`；冰雪三拼只是在冰雪键道的字母码后补轻声 `a`）。不能让棱镜同时收两套声母来兼容：那样 `dlxm` 在冰雪三拼下会把造好的「哆啦A梦」顶到「多线」前面。

所以改任一方案 `speller/algebra` 里的字母规则时，要么保持声母一致，要么拆棱镜；需要同步改的还有棱镜的 algebra 和 `snow_sanpin.fixed.txt` 的「字母」段。

## lua 的三处坑

- **代理码路径必须走 `snow.prepare`，不要自己 yield。** 冰雪三拼的 `table_like.lua` 把输入改写成代理码（`dlkm` → `dl km`、补 `?`）再查词，librime 会把补出来的 ` ` `?` `~` 算进 quality，`snow.prepare` 负责把这部分虚高和 `_end` 一起修正回来。
- **`fini` 里不能读 `env.engine.schema`。** librime 切换方案时先换 `schema_` 再销毁旧组件，`fini` 读到的是新方案的 `schema_id`。`snow.get_db` / `release_db` 按方案名引用计数，名字要在 `init` 里记到 `env` 上（如 `env.user_dict_name`），`fini` 用记下的那个。记错名字时旧方案的 LevelDB 会一直占着 `LOCK`，表现为同步时「刚切走的那个方案」报 `Error opening db ... already held by process`。
- **`LevelDb(name)` 建的库会被 Rime 同步当成用户词典。** 键必须是 `编码 \t词` 形式（恰好一个 `\t`，前面带空格），否则快照导出时被丢掉；值必须是 `c=… d=… t=…`，否则合并时被改写成 0。合并对同一个键取 `c` 的最大值，所以要跨设备同步的计数应带上 installation_id 且只增不减，参见 `statistics.lua`。

## 输入统计（`statistics.lua`）

统计口径、设计取舍和实现细节见 [docs/statistics.md](docs/statistics.md)，改动统计逻辑前先读。其中会影响其他模块的约定：

- **以后新写的直接上屏一律调用 `snow.commit_text`**：`engine:commit_text` 不触发 `commit_notifier`，否则这次上屏的字数会漏记，它的按键也会被算进下一次上屏。
- 顶屏、略码等「触发键属于下一个词」的上屏，要在上屏**之前**设置 `snow.handover`，上屏后置回 `nil`。popping 非缓冲时 `confirm_current_selection()` 就会上屏，所以要设在 confirm 之前。
- 改动统计逻辑后按文档的「验证方法」检查两个不变式，spec 里没有统计的用例。

## lua 编码规范

`lua/snow/` 下自写的组件统一按以下写法；`calculator.lua` 的函数库部分是外来代码，不强求。

**文件结构**

- 顺序：头注释（`-- xxx处理器` + 一句说明）→ 空行 → `local snow = require "snow.snow"`（用不到 `snow` 就不 require）→ `---@class XxxEnv: Env` → 组件表 → `return`。`statistics.lua` 的头注释另外包含给用户看的用法和各量说明。
- 组件表按类型命名为 `processor` / `segmentor` / `translator` / `filter`，不用 `this`、`select` 之类；一个文件导出多个组件时（`table_like.lua`）用各自的名字，`return { a = a, ... }`。
- translator 也写成表加 `init` / `func`，不写成裸函数返回。配置（如 `lua/input`）在 `init` 里读到 `env` 上，不要在 `func` 里每次读。
- 没有内容的 `init` / `fini` 直接省略。

**命名与注解**

- `env` 的类型名为「模块名 + Env」：`FixEnv`、`UserDictEnv`、`ShapeFilterEnv`。每个 `---@param env` 标注本模块的类，没有扩展字段时用 `Env`，不借用别的模块的类。
- 参数名固定：processor 为 `(key_event, env)`，translator 为 `(input, segment, env)`，filter 为 `(translation, env)`、`tags_match(segment, env)`。
- 局部变量和字段用 snake_case。

**作用域**

- 不定义全局变量或全局函数，辅助函数一律 `local function`，需要被别处调用的挂在组件表上。所有方案共用一个 Lua 状态，全局名会互相覆盖。
- 必须让外部代码看到的名字（如计算器给 `load` 求值用的函数）放进专用环境表，`load(chunk, name, "t", env)`，不要放进 `_G`。

**生命周期**

- filter 必须写 `tags_match`，只在需要处理的段上运行（多数是 `abc`，反查类再加 `pinyin`）；不按标签而按开关或配置生效的（`unicode`、`special`）也通过 `tags_match` 判断。
- `notifier:connect` 的返回值必须存到 `env` 上并在 `fini` 里 `disconnect()`。context 跨方案存活，不断开的话每次切换方案都会多挂一份回调。
- `fini` 负责：断开连接；`snow.release_db` 释放用户词典；把 `Memory`、`ReverseLookup`、`Component.*` 等 C++ 对象置 `nil` 后 `collectgarbage()`。普通 Lua 表不用手动清。

**语法细节**

- 只有 `nil` 和 `false` 为假，`0`、空字符串和空表都为真。判空字符串用 `s == ""`，连续数组用 `#list == 0`，字典用 `next(map) == nil`；`not value` 只用来判断真假或是否缺值。
- `a and b or c` 只有在 `b` 不会为 `false` 或 `nil` 时才能代替条件表达式，否则写 `if` 分支。`0` 和 `""` 不会触发 `or` 的后备值。
- `require "x"` 不加括号；字符串用双引号，内容含 `"` 时才用单引号；行尾不加分号。
- 字符串操作用方法调用：`input:sub(1, 1)`，不写 `string.sub(input, 1, 1)`。
- `if` 条件不加多余括号。
- 2 空格缩进，不用 tab。

**类型检查**

`lua/snow/` 下自写的文件应当没有 lua-language-server 警告（编辑器里按 strict 级别检查，含 `no-unknown`）。VS Code 只分析打开过的文件，要一次查全用扩展自带的命令行：

```sh
echo '{"diagnostics.groupFileStatus":{"strict":"Any","strong":"Any"},"diagnostics.disable":["lowercase-global"]}' > "$TMPDIR/luarc.json"
~/.vscode/extensions/sumneko.lua-*/server/bin/lua-language-server --check="$PWD" \
  --configpath="$TMPDIR/luarc.json" --checklevel=Warning --logpath="$TMPDIR/luals" --check_format=json
```

末行给出总数，逐条结果在 `$TMPDIR/luals/check.json`。容易触发警告的几种写法：

- `snow.get_db` 在库被别的进程锁住时返回 `nil`，所以持有它的字段要标 `LevelDb|nil`，用之前判空。
- 下标从 0 开始的表（如 `number.lua` 的 `digits`）标 `table<integer, string>`，不要标 `string[]`：后者用 `[0]` 取值推不出类型。索引它的键也必须是 integer，`tonumber()` 返回 `number?`，不行，数字字符可以用 `s:byte(i) - 48`。
- 用字面量建的、以字符串为键的查找表（如 `{ a = "j", e = "q" }`）用变量去索引时推不出类型，要标 `---@type table<string, string>`。函数里先建空表再逐项填的局部变量同理，要标元素类型。
- 一个 `if` 的某个分支给变量赋字面量（`x = ""`），另一个分支写 `x = x:sub(1, -2)`，后者会报 `no-unknown`，加 `---@type` 也没用（LuaLS 的问题）。改成一个表达式 `x = cond and "" or x:sub(1, -2)`。

## 冰雪一拼的功能并击

功能并击最多使用三键，不要新增四键并击。`jkl`、`uio`、`m,.` 分别输入统计命令 `itj`、`itjf`、`itjh`；`jio` 直接开启缓冲。冰雪一拼不提供 Unicode 输入。

## processors 顺序

五个顶功方案（冰雪四拼、冰雪三拼、冰雪一拼、冰雪键道、冰雪清韵）共用一套相对顺序，新增或移动处理器时按下表对齐：

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

### 判定规则：这个键会不会被顶功吃掉

`popping` 通过前置守卫（非 release / alt / ctrl / caps，当前段带 `abc` tag）后，**必定** `env.engine:process_key()` 从链顶重投按键并返回 `kAccepted`。所以排在 popping 之后只是晚一轮收到键。判定处理器 P 的位置：

1. P 想要的键落在本方案 `speller/popping` 某条规则的 `accept` 里 → popping 会先顶屏，P 必须排在 popping **之前**；
2. 不落在里面 → **默认排后面**；
3. 特例：P 故意只认小写、靠 popping 的大写→小写转换来触发 → 必须排在 popping **之后**。

### 硬约束

- `shape_processor` < `popping`：辅助码键在顶功的 accept 里（冰雪一拼的 `combo_popping` 在完整音节后任何小写字母都顶屏）。
- `abbreviation` < `popping`：略码用大写，排后面会收到被转成小写的键。
- `select_character` < `popping`：`[` `]` 命中「标点大写顶」。
- `popping` < `recognizer`：冰雪键道的 `recognizer/patterns/jianpin` 无前缀，会匹配普通编码并自己 `PushInput`，排前面会让 3 码以上的顶功静默失效（短码正常，容易漏测）。
- `popping` < `editor`：冰雪清韵的回头补码靠大写元音命中 `strategy: append` 规则后转小写重投给 editor；editor 排前面会让小写元音直接补码。
- `user_dict` < `key_binder`：`Control+bracketleft` 被绑成了 Escape。user_dict 的上移/下移分支落空时也要返回 `kAccepted`，否则会穿透成 Escape 清空整句。
- `shape_processor` < `key_binder`：冰雪四拼的 `1` 既是辅助码触发键又被绑成「定位」。
- `statistics` 排第一：它只计数，除并击的最后一次松开外都返回 `kNoop`，要在其他处理器吃掉按键之前看到每个键，包括被 `ascii_composer` 吃掉的临时西文按键（靠它们判断临时西文是否上屏，以便丢掉之前累计的按键）。全局英文和临时西文由它自己按 `ascii_mode` 跳过；popping 重投的那一次靠 `snow.redispatching` 去重。
- 其余沿用 Rime 原生顺序。

拿不准的那一对不要按多数方案的现状定，跑 mira。另外，某个功能用小写键测像是完全失效时，可能是靠大写回投在工作（如冰雪清韵的 editor），要连大写一起测。

### 验证

改动 processors 后跑全部五份 spec：

```sh
bun scripts/test.ts
```

手工逐键探查用 `~/Public/librime` build 里的 `rime_console -i`（带 librime-lua）：把仓库 rsync 到临时目录，补上 `default.yaml`／`essay.txt` 和只含待测方案的 `default.custom.yaml`。每行一个按键，非字母键写成 `{bracketleft}`、`{Control+bracketleft}`；输出的 `comp. : [{abc,jianpin}dejx=>得奖]` 会显示当前段的 tag。

## segmentors / translators / filters 顺序

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

**改 preedit 的 filter 必须排在 `uniquifier` 之前**（如 `shape_filter` 的辅助码提示）：合并后的 `UniquifiedCandidate::preedit()` 恒返回首个被合并候选的 preedit，写在包装器上的会被丢弃。`comment` 不受影响。

## 一致性自查

改完任一段落后跑一遍，四个段落都应为 0。它只报「两个组件在不同方案里前后相反」，不报缺组件（多数是刻意的）。

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
