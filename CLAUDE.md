# 冰雪拼音开发约定

**始终用中文回复。**

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

## 实际目录

`~/.local/share/fcitx5/rime` 里的 `snow_*.schema.yaml`、`snow_*.dict.yaml`、`snow_*.fixed.txt`、`lua/snow` 都是指回本仓库的软链，**没有「同步」这一步**：改哪边都是改同一份文件，`git pull` 后重新部署即可。

```sh
bun scripts/link.ts link      # 建立软链（幂等，仓库新增文件后重跑；冲突时中止，确认后加 --force）
bun scripts/link.ts unlink    # 还原成独立副本
```

手机上的仓输入法读的是 iCloud 里的 `RimeUserData/rime-snow-pinyin`。iCloud 不跟随软链，所以那边只能复制：`bun scripts/link.ts sync` 把同样的文件加上 `rime-stroke/stroke*` 单向镜像过去，只复制内容有变化的文件，并清理仓库里已删除的文件。这一步要手动跑，改完想在手机上用时再跑一次。

本机私有、已被 `.gitignore` 排除的 `*.custom.yaml`、`*.userdb`、`build/`、`user.yaml`、`installation.yaml` 仍各自独立，所以在仓库里跑 mira 不会污染实际词频。

改动 lua 后重新部署即可生效：部署会重建 Lua 状态，所有模块重新 `require`，不用重启输入法。

## 版本号

版本号只写在 `lua/snow/snow.lua` 的 `snow.version` 里，不要手改 yaml。改版本时运行

```sh
bun scripts/version.ts 0.3.12   # 改写 snow.lua 和所有 snow_*.schema.yaml、snow_*.dict.yaml
bun scripts/version.ts          # 查看当前版本
```

词典生成脚本（`single.ts`、`multiple.ts`、`generateYingpinDict.ts`）也从 `scripts/version.ts` 读取同一个版本号。Rime 的 `__include` 只在方案里生效，词典头不支持，所以没法靠 yaml 本身共用一份。

## 测试

测试位于 `spec/*.test.yaml`，由 [mira](https://github.com/rimeinn/mira) 运行。日常用 `scripts/test.ts`，五个方案并行，全部跑完约 40 秒；失败时只打印失败用例，完整输出留在它给出的临时目录里：

```sh
bun scripts/test.ts                  # 全部五个方案
bun scripts/test.ts yipin qingyun    # 只跑指定方案，snow_ 前缀可省
```

它为每个方案准备一份独立环境，这几步都是为了提速或者能并行，不要省掉：

- **精简的源目录**：mira 的每个 deploy 都会把整个 `source_dir`（spec 里写的是 `..`，也就是整个仓库，带 `.git`、`node_modules`、`cache`，约 1 GB）复制一遍。脚本只复制 `git ls-files -co --exclude-standard` 列出的文件，再加上 `rime-stroke/stroke*`，相当于 CI 的全新 checkout。本机的 `*.userdb`、`user.yaml` 自然被排除在外，不用再 `rm -rf *.userdb`。
- **`default.custom.yaml` 只留被测方案**：否则每个 deploy 都要检查 `schema_list` 里的全部五个方案。这两项加起来，每个 deploy 从约 4 秒降到约 1.4 秒。
- **独立的 `TMPDIR`**：mira 的工作目录写死为 `$TMPDIR/mira`，启动时整个删掉，两个 mira 同时跑会互相删目录然后崩溃。
- **独立的缓存副本**：`-C` 指向的 staging 目录不能共用。带 `patch` 的 deploy（冰雪三拼、冰雪键道的 `sentence`，冰雪四拼的 `special`）会把改过的方案编译进缓存，改了词典后几个进程还会同时重建同一份 `.bin`。脚本先把仓库的 `cache/` 复制给每个方案，跑完再把更新过的文件写回去。

只调一个 deploy 时直接用 mira 的 `-R` 更快，但这会用仓库本身作 `source_dir`，所以要自己清词频，同时也不能有别的 mira 在跑：

```sh
cp rime-stroke/stroke* .          # 笔画反查依赖
rm -rf *.userdb                   # 清掉上次运行累积的词频，与 CI 的全新 checkout 对齐
mira -C cache -R '^popping$' spec/snow_sipin.test.yaml
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
    - script_translator@pinyin            # 冰雪一拼无
    - lua_translator@*snow.datetime       # 冰雪一拼无
    - lua_translator@*snow.statistics*translator
    - lua_translator@*snow.number         # 以下冰雪一拼均无
    - lua_translator@*snow.calculator
    - history_translator

  filters:
    - lua_filter@*snow.placeholder        # 冰雪一拼无
    - lua_filter@*snow.enforce            # 仅冰雪键道
    - reverse_lookup_filter@lookup_pinyin # 冰雪一拼、冰雪清韵无
    - reverse_lookup_filter@lookup_<方案>  # 同上
    - lua_filter@*snow.fix
    - lua_filter@*snow.shape_filter       # 冰雪清韵用 *snow.qingyun 占这个位置
    - lua_filter@*snow.postpone           # 冰雪一拼无
    - uniquifier                          # 冰雪清韵无
    - simplifier                          # 冰雪清韵无
    - lua_filter@*snow.hint               # 冰雪四拼用 *snow.special；冰雪一拼、冰雪清韵无
    - lua_filter@*snow.unicode
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
