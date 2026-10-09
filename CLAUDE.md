# 冰雪拼音开发约定

**始终用中文回复。**

## 实际目录

`~/.local/share/fcitx5/rime` 里的 `snow_*.schema.yaml`、`snow_*.dict.yaml`、
`snow_*.fixed.txt`、`lua/snow` 都是指回本仓库的软链，**没有「同步」这一步**：改哪边都是
改同一份文件，`git pull` 后重新部署即可。

```sh
bun scripts/tasks.ts link      # 建立软链（幂等，仓库新增文件后重跑；冲突时中止，确认后加 --force）
bun scripts/tasks.ts unlink    # 还原成独立副本
```

本机私有、已被 `.gitignore` 排除的 `*.custom.yaml`、`*.userdb`、`build/`、`user.yaml`、
`installation.yaml` 仍各自独立，所以在仓库里跑 mira 不会污染实际词频。

改动 lua 后**必须重启输入法**才生效，重新部署不会重建 Lua 状态。

## 测试

测试位于 `spec/*.test.yaml`，由 [mira](https://github.com/rimeinn/mira) 运行：

```sh
cp rime-stroke/stroke* .          # 笔画反查依赖
rm -rf *.userdb                   # 清掉上次运行累积的词频，与 CI 的全新 checkout 对齐
mira -C cache spec/snow_sipin.test.yaml
```

- 断言里只有 `cand`（元素含 `.text`、`.comment`）、`preedit`、`commit`；`assert` 会被包进
  `return (...)`，只能写表达式。
- `has()` 扫描全部候选（可达上百个），文档说「出现在首页」时用 `page()`（`page_size` 为 6）。
- **造词类用例断言 `cand[1]`，不要断言 `commit`。** 用例末尾的两个空格会把缓冲区上屏，
  `commit` 恒等于想造的词，不管词有没有进用户词典。
- 固定词（`snow_*.fixed.txt`）**每一类只测一例**，不要把方案文档里的清单逐条搬进测试；
  要验整份词表就直接比对 fixed.txt。
- 临时探查状态可写 `assert: error(...)`，消息会打进 stderr。`assert` 的值不加引号，
  空格后的 `#` 会被当成注释，要写成 `tostring(#cand)` 之类。

### 按部署隔离会改变状态的用例

同一个 `deploy` 内各 `send` 共享用户词典。动态码长会让上屏过的词迁到更短的编码上，并从
原编码的首选消失（`bxouivrf` 上屏「冰雪」后，`bxoui` 的首选就不再是「冰雪」）。因此：

- 依赖原始词频的断言放在 `popping` 部署，排在所有上屏类用例之前；
- 动态码长、自动造词、缓冲造词等写用户词典的用例放进独立部署（`encoding` / `buffered` /
  `schema_userdb`）。

## 简拼棱镜

键道和三拼共用 `snow_jiandao_jianpin` 按纯声母查多字词，前提是两边**英数字母的声母一致**
（辅音字母是该字母，元音字母都是 `x`；三拼只是在键道的字母码后补轻声 `a`）。不能让棱镜
同时收两套声母来兼容：那样 `dlxm` 在三拼下会把造好的「哆啦A梦」顶到「多线」前面。

所以改任一方案 `speller/algebra` 里的字母规则时，要么保持声母一致，要么拆棱镜；
需要同步改的还有棱镜的 algebra 和 `snow_sanpin.fixed.txt` 的「字母」段。

## lua 的三处坑

- **代理码路径必须走 `snow.prepare`，不要自己 yield。** 三拼的 `table_like.lua` 把输入改写成
  代理码（`dlkm` → `dl km`、补 `?`）再查词，librime 会把补出来的 ` ` `?` `~` 算进 quality，
  `snow.prepare` 负责把这部分虚高和 `_end` 一起修正回来。
- **`fini` 里不能读 `env.engine.schema`。** librime 切换方案时先换 `schema_` 再销毁旧组件，
  `fini` 读到的是新方案的 `schema_id`。`snow.get_db` / `release_db` 按方案名引用计数，
  名字要在 `init` 里记到 `env` 上（如 `env.user_dict_name`），`fini` 用记下的那个。
  记错名字时旧方案的 LevelDB 会一直占着 `LOCK`，表现为同步时「刚切走的那个方案」报
  `Error opening db ... already held by process`。
- **`LevelDb(name)` 建的库会被 Rime 同步当成用户词典。** 键必须是 `编码 \t词` 形式（恰好一个
  `\t`，前面带空格），否则快照导出时被丢掉；值必须是 `c=… d=… t=…`，否则合并时被改写成 0。
  合并对同一个键取 `c` 的最大值，所以要跨设备同步的计数应带上 installation_id 且只增不减，
  参见 `statistics.lua`。

## 输入统计（`statistics.lua`）

给用户看的用法和各量的一行说明在文件头注释里，这里记录统计口径和设计取舍，改动前先读。

### 结构

- `lua_processor@*snow.statistics*processor` 排在 processors **第一位**，只观察按键，恒返回
  `kNoop`。它把每个计入的键追加到 `env.steps`，在每次上屏时结算写库。排第一是因为
  `ascii_composer` 会吃掉临时西文的空格和回车，`shape_processor`、`select_character` 等也会
  `kAccepted` 掉按键，排在它们后面就看不到这些键了。
- `lua_translator@*snow.statistics*translator` 紧跟在 `datetime` 后面，处理 `otj` / `otjq` /
  `otjs` / `otjd`。如果排在 `calculator` 后面，首选会被计算器回显的 `tj` 抢走。
- 接入的方案：sipin、sanpin、jiandao、qingyun；yipin 未接入。命令前缀取自 `lua/input`，和
  datetime、number、calculator 共用：多数方案是 `o`，qingyun 的 `o` 是普通编码，所以用两个着重号
  ``` `` ```。单个 `` ` `` 在 qingyun 里引导拼音、笔画反查和重复上屏，对应的 recognizer 规则
  （`` ^`[a-z]*'?$ ``、`` ^`$ ``）都匹配不到第二个字符是 `` ` `` 的输入，所以 `` ^``.*$ `` 和它们
  互不重叠。
- 前缀可以是多个字符，各 lua 翻译器要按 `#env.prompt` 比较和截取，不能写 `input:sub(1, 1)`。

### 存储与同步

- 只有一个库 `snow_statistics.userdb`，所有方案、所有安装共用，通过 `snow.get_db` /
  `release_db` 做引用计数。processor 和 translator 各持有一次引用。
- 键为 `<schema_id> <YYYYMMDD> <installation_id> \t<字段>`，值为 `c=<计数> d=0 t=1`。这是用户
  词典快照的格式，见「lua 的三处坑」：librime 同步时把所有 `.userdb` 当用户词典处理，格式不对
  的键会被丢掉，格式不对的值会被改写成 0。
- 只存逐日的原始计数，比率在显示时再算。计数可以相加、可以合并、可以同步；周、月、年的数字
  在查询时把各天加起来，库里没有无限增长的数组。一天的 `duration` 最多约
  $8.64\times10^7$ ms，不会超出 `c=` 解析用的 int。
- 多设备同步：每个安装只写带自己 `installation_id`（即 `rime_api.get_user_id()`）的键，而且所有
  计数**只增不减**。`UserDbMerger` 对同一个键取 `c` 的最大值，结果正好是该安装的最新值；重复
  同步结果不变（用 `rime_dict_manager -b` / `-r` 实测过往返）。为了保证单调：
  - 有效按键结算出负数时，余额留到下次结算（`env.carry`），不写负增量；
  - 极速只在更大时覆盖。
  - 两台设备的 `installation_id` 相同时，它们的数据会按最大值互相覆盖，这是这种方案的前提。
- 日期取结算（上屏）那一刻的本地日期。

### 哪些按键计入（`processor.func`）

1. `snow.redispatching` 为真时跳过：popping 用 `engine:process_key()` 把同一个键重投到链顶，
   第一次已经记过了。
2. 所有 release 事件都跳过。修饰键（`0xffe1`–`0xffee`）按下时只记下来（`env.tap`），松开时
   如果中间没按过别的键、而且正在输入，就算一个键，例如切换临时西文的 Shift。修饰键和别的键
   一起按时，整组只算在那个键上。
3. 有编码时，其余按下的键全部计入，包括 Ctrl/Alt 组合键（整组算一个）、退格、方向键、Escape、
   空格、选重键。
4. 没有编码时，只计入 `0x20`–`0x7e` 的可见字符，并且要求没有按 Ctrl/Alt/Super、不处在全局
   英文状态（`ascii_mode`）。也就是只算会开始一段输入、或会直接上屏的键；快捷键和全局英文
   下的输入属于应用，不算。

每个计入的键 $k$ 记两个量：

$$
e_k=\begin{cases}-1 & k\text{ 是退格}\\ +1 & \text{其他}\end{cases}
\qquad
\delta_k=\begin{cases}t_k-t_{k-1} & t_k-t_{k-1}<T_\text{idle}\\ 0 & \text{其他}\end{cases}
$$

其中 $t$ 取自 `rime_api.get_time_ms()`，是单调时钟的毫秒数（不是墙上时间，只能用来算间隔）。
$t_{k-1}$ 是上一个计入的键的时刻，$T_\text{idle}=5000$ ms。停顿之后的第一个键 $\delta=0$。

### 上屏从哪里来

| 来源 | 捕获方式 | 记作的上屏文字 |
| --- | --- | --- |
| `context:commit()`：选词、空格、顶屏、回车上屏编码、标点 | `commit_notifier` | `get_commit_text()` |
| 没有编码时直接放行给应用的可见字符（数字、空格等） | `unhandled_key_notifier` | 这个字符 |
| `snow.commit_text`：以词定字、略码、英拼的空格 | `property_update_notifier`，属性名 `commit_text` | 属性值 |
| 临时西文的空格、回车（`ascii_composer` 调用 `engine:CommitText`） | processor 按 `ascii_composer` 的规则自己补记 | `input`，空格时再加一个空格 |

- `engine:commit_text` 不触发 `commit_notifier`。**以后新写的直接上屏一律调用
  `snow.commit_text`**，否则这次上屏的字数会漏记，它的按键也会被算进下一次上屏。
- `unhandled_key_notifier` 对 `kRejected` 的键也会触发，所以回调里要排除 `ascii_mode`；还要
  排除 `snow.redispatching`，因为顶屏后重投、最终没人处理的键（比如空格）并没有到达应用。

### 按键归到哪次上屏

设第 $j$ 次上屏的文字为 $c_j$，结算时 `env.steps` 里有 $n_j$ 个键。结算的是前
$n_j-h_j$ 个，组成集合 $K_j$；最后 $h_j$ 个留给下一次上屏。

$h_j$ 就是 `snow.handover`：popping 按规则顶屏时取 $1+\ell$，$\ell$ 是因 `rule.prefix` 被推回
输入框的编码长度；其他上屏都取 $0$。

这样设计的原因：

- 口径定为「两次上屏之间的按键」，所以选重键、上屏键算在这个词上：四拼「s + 空格」输入「我」
  是 2 码。
- 顶屏键在时间上先于上屏，但它是下一个词的首码，所以要转出去：`bis␣` 先后上屏「比」「我」，
  两个都是 2 码，而不是 3 码和 1 码。
- 不能等收到重投的键之后再把它从上一次上屏里挪走：那样就得把已经写进库的 `code<i>` 减一，
  违反单调性，同步合并时会被旧值盖回去。所以要由 popping 在上屏**之前**声明 handover。
- 只有规则命中、重投之前的那次上屏才设置 handover。重投之后发生的上屏（重投的标点被
  punctuator 上屏、`auto_select_pattern` 触发的自动上屏、空格选词）都不设置，这时的键确实
  属于这次上屏。
- 非缓冲模式下 popping 开着 `_auto_commit`，`confirm_current_selection()` 这一步就会上屏，
  所以 handover 必须在 confirm **之前**设置。第一版把它设在 `commit()` 前面，结果完全没有生效。

### 统计量

所有和式都取某个「方案 × 日期 × 安装」内的全部上屏。$|c|$ 表示 UTF-8 字符数。

| 字段 | 定义 |
| --- | --- |
| `chars` 字数 | $\sum_j \lvert c_j\rvert$ |
| `keys` 按键 | $\sum_j \lvert K_j\rvert$ |
| `effective_keys` 有效按键 | $\sum_j E_j$，见下 |
| `duration` 时长（ms） | $\sum_j\sum_{k\in K_j}\delta_k$ |
| `fastest` 极速（字/分） | 见下 |
| `word<i>` 词长分布 | $\#\{j:\lvert c_j\rvert=i\}$ |
| `code<i>` 码长分布 | $\#\{j:E_j=i\}$，$i\ge 0$ |

**有效按键**带一个跨上屏的余额 $r$（`env.carry`，初值 0）：

$$
\tilde E_j=r_{j-1}+\sum_{k\in K_j}e_k,\qquad E_j=\max(\tilde E_j,0),\qquad r_j=\min(\tilde E_j,0)
$$

有编码时每按一次退格，它本身让 `keys` 加 1、`effective_keys` 减 1，被删掉的那个键之前也给两边
各加过 1，所以两者的差值增加 2。有效按键近似于「不打错时需要的按键数」。只有在退格多于其他键时
（例如顶屏后删掉推回的编码）才会出现负的 $\tilde E_j$。

**码长按有效按键算，而不是按 `ctx.input` 的长度算**：`input` 不含辅助码（sipin 的辅助码存在
`shape_input` 属性里）、选重键和上屏键，没法和按键数对上。

**两个恒等式**严格成立：

$$
\sum_i i\cdot\text{word}_i=\text{chars},\qquad \sum_i i\cdot\text{code}_i=\text{effective\_keys}
$$

这是因为每次结算时，`word`/`code` 档位与 `chars`/`effective_keys` 的增量取自同一个数，并且
**档位不设上限**。以后改口径时，用这两个等式来检查。$E_j=0$ 的上屏记进 `code0`，例如略码重复
出来的那一份。它对第二个等式没有影响。

**极速**：在当前会话（engine 实例）内，把连续若干次上屏的字数和时长累加成一个窗口，
时长 $D_W\ge 60\,\text{s}$ 时结算 $v=\lfloor 60000\cdot\text{chars}_W/D_W\rfloor$，只有比当天
已记录的值大才覆盖，然后清空窗口重新累计。窗口不滑动，所以它不是严格的「最快一分钟」，而是
「某段至少一分钟的输入的平均速度」的最大值。

### 报告里的派生量

记 $D$ 为 `duration`，单位 ms：

$$
\text{均速}=\frac{60000\cdot\text{chars}}{D}\ \text{字/分},\quad
\text{击键}=\frac{1000\cdot\text{keys}}{D}\ \text{键/秒},\quad
\text{码长}=\frac{\text{keys}}{\text{chars}},\quad
\text{键准}=\frac{\text{effective\_keys}}{\text{keys}},\quad
\text{理论码长}=\frac{\text{effective\_keys}}{\text{chars}}
$$

- 分布显示的是各档占上屏次数的比例，长度用中文数字（100 以上用阿拉伯数字）。
- 周、月、年把各天的计数相加，`fastest` 取最大值；本周从周一算起。
- `otjq` 把各安装的计数相加；`otjs` 列出本年有数据的安装。
- 报告只看当前方案。导出则包含全部方案、全部安装，每行是「方案 × 日期 × 安装」，分布列写成
  `1:n1 2:n2 …`。

### 其他取舍

- 方案之间码长不可比，所以按方案分开统计；设备之间速度不可比（电脑和手机），所以按安装分开统计。
- 时长不计超过 5 秒的停顿，衡量的是打字本身，不是想内容的时间。
- 不记录上屏的文字本身：一是出于隐私，二是旧脚本那种「生字本」的判定（距上次上屏超过 3 秒）
  主要是噪声。

### 已知局限

- 缓冲模式下的顶屏只 confirm 不上屏，handover 不起作用；缓冲区整体上屏时，按键都算在那一次上。
- handover 假设推回输入框的每个编码字符对应一个有效按键，被推回的编码如果经过回改会有偏差。
- 通过 `ascii_composer` 的 `commit_raw_input` 等按键绑定从临时西文上屏时，实际上屏的是
  `raw_keys_`，而补记用的是 `context.input`，字数可能略有出入。默认的空格、回车是准确的。
- 极速窗口不跨会话：切换方案或重启输入法时，没满一分钟的窗口会被丢掉；跨零点的窗口记在
  结算那天。
- mira 里所有按键都是瞬间完成的，测出的时长和速度没有意义，spec 只断言报告格式。

### 验证方法

改动统计逻辑后，除了跑 spec，还要用临时用例混合各种上屏方式，导出后检查两个恒等式。mira 的
数据目录是 `$TMPDIR/mira/data/`，**每个 deploy 都会重建**，所以临时用例只写一个 deploy，并把
`otjd` 放在最后：

```sh
python3 - "$TMPDIR/mira/data/snow_statistics.tsv" <<'PY'
import csv, sys
for r in csv.DictReader(open(sys.argv[1]), delimiter="\t"):
    f = lambda k: sum(int(a) * int(b) for a, b in (x.split(":") for x in r[k].split()))
    assert f("word_distribution") == int(r["chars"]), r
    assert f("code_distribution") == int(r["effective_keys"]), r
PY
```

要追踪每个键、每次结算，就临时在 `processor.func` / `record` 里用 `io.open(..., "a")` 写一个
文件。`log.error` 和 stderr 在 mira 的输出里都看不到。

## lua 编码规范

`lua/snow/` 下自写的组件统一按以下写法；`input_statistics.lua`（未接入任何方案）和
`calculator.lua` 的函数库部分是外来代码，不强求。

**文件结构**

- 顺序：头注释（`-- xxx处理器` + 一句说明）→ 空行 → `local snow = require "snow.snow"`
  （用不到 `snow` 就不 require）→ `---@class XxxEnv: Env` → 组件表 → `return`。
  `statistics.lua` 的头注释另外包含给用户看的用法和各量说明。
- 组件表按类型命名为 `processor` / `segmentor` / `translator` / `filter`，不用 `this`、
  `select` 之类；一个文件导出多个组件时（`table_like.lua`）用各自的名字，`return { a = a, ... }`。
- translator 也写成表加 `init` / `func`，不写成裸函数返回。配置（如 `lua/input`）在
  `init` 里读到 `env` 上，不要在 `func` 里每次读。
- 没有内容的 `init` / `fini` 直接省略。

**命名与注解**

- `env` 的类型名为「模块名 + Env」：`FixEnv`、`UserDictEnv`、`ShapeFilterEnv`。每个
  `---@param env` 标注本模块的类，没有扩展字段时用 `Env`，不借用别的模块的类。
- 参数名固定：processor 为 `(key_event, env)`，translator 为 `(input, segment, env)`，
  filter 为 `(translation, env)`、`tags_match(segment, env)`。
- 局部变量和字段用 snake_case。

**作用域**

- 不定义全局变量或全局函数，辅助函数一律 `local function`，需要被别处调用的挂在组件表上。
  所有方案共用一个 Lua 状态，全局名会互相覆盖。
- 必须让外部代码看到的名字（如计算器给 `load` 求值用的函数）放进专用环境表，
  `load(chunk, name, "t", env)`，不要放进 `_G`。

**生命周期**

- filter 必须写 `tags_match`，只在需要处理的段上运行（多数是 `abc`，反查类再加 `pinyin`）；
  不按标签而按开关或配置生效的（`unicode`、`special`）也通过 `tags_match` 判断。
- `notifier:connect` 的返回值必须存到 `env` 上并在 `fini` 里 `disconnect()`。context 跨方案
  存活，不断开的话每次切换方案都会多挂一份回调。
- `fini` 负责：断开连接；`snow.release_db` 释放用户词典；把 `Memory`、`ReverseLookup`、
  `Component.*` 等 C++ 对象置 `nil` 后 `collectgarbage()`。普通 Lua 表不用手动清。

**语法细节**

- `require "x"` 不加括号；字符串用双引号，内容含 `"` 时才用单引号；行尾不加分号。
- 字符串操作用方法调用：`input:sub(1, 1)`，不写 `string.sub(input, 1, 1)`。
- `if` 条件不加多余括号。
- 2 空格缩进，不用 tab。

## processors 顺序

五个顶功方案（sipin / sanpin / yipin / jiandao / qingyun）共用一套相对顺序，新增或移动
处理器时按下表对齐：

```yaml
  processors:
    - lua_processor@*snow.statistics*processor  # yipin 无
    - ascii_composer
    - chord_composer                        # 仅 yipin
    - lua_processor@*snow.shape_processor    # qingyun 无
    - lua_processor@*snow.abbreviation      # 仅 sipin
    - lua_processor@*snow.select_character  # yipin 无
    - lua_processor@*snow.popping           # yipin 用 combo_popping
    - recognizer
    - lua_processor@*snow.user_dict         # yipin 无
    - key_binder
    - lua_processor@*snow.editor            # 仅 sipin、qingyun
    - speller
    - punctuator
    - selector
    - navigator
    - express_editor
```

### 判定规则：这个键会不会被顶功吃掉

`popping` 通过前置守卫（非 release / alt / ctrl / caps，当前段带 `abc` tag）后，**必定**
`env.engine:process_key()` 从链顶重投按键并返回 `kAccepted`。所以排在 popping 之后只是晚
一轮收到键。判定处理器 P 的位置：

1. P 想要的键落在本方案 `speller/popping` 某条规则的 `accept` 里 → popping 会先顶屏，
   P 必须排在 popping **之前**；
2. 不落在里面 → **默认排后面**；
3. 特例：P 故意只认小写、靠 popping 的大写→小写转换来触发 → 必须排在 popping **之后**。

### 硬约束

- `shape_processor` < `popping`：辅助码键在顶功的 accept 里（yipin 的 `combo_popping`
  在完整音节后任何小写字母都顶屏）。
- `abbreviation` < `popping`：略码用大写，排后面会收到被转成小写的键。
- `select_character` < `popping`：`[` `]` 命中「标点大写顶」。
- `popping` < `recognizer`：jiandao 的 `recognizer/patterns/jianpin` 无前缀，会匹配普通
  编码并自己 `PushInput`，排前面会让 3 码以上的顶功静默失效（短码正常，容易漏测）。
- `popping` < `editor`：qingyun 的回头补码靠大写元音命中 `strategy: append` 规则后转小写
  重投给 editor；editor 排前面会让小写元音直接补码。
- `user_dict` < `key_binder`：`Control+bracketleft` 被绑成了 Escape。user_dict 的上移/下移
  分支落空时也要返回 `kAccepted`，否则会穿透成 Escape 清空整句。
- `shape_processor` < `key_binder`：sipin 的 `1` 既是辅助码触发键又被绑成「定位」。
- `statistics` 排第一：它只计数、恒返回 `kNoop`，要在其他处理器吃掉按键之前看到每个键，
  包括 `ascii_composer` 临时西文下用来上屏的空格、回车（这类上屏不经过 `commit_notifier`）。
  全局英文状态由它自己按 `ascii_mode` 跳过；popping 重投的那一次靠 `snow.redispatching` 去重。
- 其余沿用 Rime 原生顺序。

拿不准的那一对不要按多数方案的现状定，跑 mira。另外，某个功能用小写键测像是完全
失效时，可能是靠大写回投在工作（如 qingyun 的 editor），要连大写一起测。

### 验证

改动 processors 后跑全部五份 spec：

```sh
for s in snow_sipin snow_sanpin snow_yipin snow_jiandao snow_qingyun; do
  mira -C cache spec/$s.test.yaml
done
```

手工逐键探查用 `~/Public/librime` build 里的 `rime_console -i`（带 librime-lua）：把仓库
rsync 到临时目录，补上 `default.yaml`／`essay.txt` 和只含待测方案的 `default.custom.yaml`。
每行一个按键，非字母键写成 `{bracketleft}`、`{Control+bracketleft}`；输出的
`comp. : [{abc,jianpin}dejx=>得奖]` 会显示当前段的 tag。

## segmentors / translators / filters 顺序

```yaml
  segmentors:
    - ascii_segmentor
    - matcher
    - abc_segmentor
    - affix_segmentor@stroke              # yipin、qingyun 无
    - affix_segmentor@pinyin              # yipin 无
    - affix_segmentor@jianpin             # 仅 jiandao
    - punct_segmentor
    - fallback_segmentor

  translators:
    - punct_translator
    - <主翻译器>                           # script_translator；sanpin 用 *snow.table_like*t12
    - <方案专属副翻译器>                    # jiandao/qingyun 的 script_translator@<方案>、
                                          # sanpin 的 *snow.table_like*jianpin
    - table_translator@stroke             # yipin 无
    - script_translator@pinyin            # yipin 无
    - lua_translator@*snow.datetime       # 以下 yipin 均无
    - lua_translator@*snow.statistics*translator
    - lua_translator@*snow.number
    - lua_translator@*snow.calculator
    - history_translator

  filters:
    - lua_filter@*snow.placeholder        # yipin 无
    - lua_filter@*snow.enforce            # 仅 jiandao
    - reverse_lookup_filter@lookup_pinyin # yipin、qingyun 无
    - reverse_lookup_filter@lookup_<方案>  # 同上
    - lua_filter@*snow.fix
    - lua_filter@*snow.shape_filter       # qingyun 用 *snow.qingyun 占这个位置
    - lua_filter@*snow.postpone           # yipin 无
    - uniquifier                          # qingyun 无
    - simplifier                          # qingyun 无
    - lua_filter@*snow.hint               # sipin 用 *snow.special；yipin、qingyun 无
    - lua_filter@*snow.unicode
```

**改 preedit 的 filter 必须排在 `uniquifier` 之前**（如 `shape_filter` 的辅助码提示）：
合并后的 `UniquifiedCandidate::preedit()` 恒返回首个被合并候选的 preedit，写在包装器上的
会被丢弃。`comment` 不受影响。

## 一致性自查

改完任一段落后跑一遍，四个段落都应为 0。它只报「两个组件在不同方案里前后相反」，
不报缺组件（多数是刻意的）。

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
