# 冰雪拼音开发约定

**始终用中文回复。**

## 实际目录

`~/.local/share/fcitx5/rime` 里的 `snow_*.schema.yaml`、`snow_*.dict.yaml`、
`snow_*.fixed.txt`、`lua/snow` 都是指回本仓库的软链，**没有「同步」这一步**：改哪边都是
改同一份文件，`git pull` 后重新部署即可。

```sh
bun scripts/link.ts link      # 建立软链（幂等，仓库新增文件后重跑；冲突时中止，确认后加 --force）
bun scripts/link.ts unlink    # 还原成独立副本
```

本机私有、已被 `.gitignore` 排除的 `*.custom.yaml`、`*.userdb`、`build/`、`user.yaml`、
`installation.yaml` 仍各自独立，所以在仓库里跑 mira 不会污染实际词频。

改动 lua 后重新部署即可生效：部署会重建 Lua 状态，所有模块重新 `require`，不用重启输入法。

## 版本号

版本号只写在 `lua/snow/snow.lua` 的 `snow.version` 里，不要手改 yaml。改版本时运行

```sh
bun scripts/version.ts 0.3.12   # 改写 snow.lua 和所有 snow_*.schema.yaml、snow_*.dict.yaml
bun scripts/version.ts          # 查看当前版本
```

词典生成脚本（`single.ts`、`multiple.ts`、`generateYingpinDict.ts`）也从 `scripts/version.ts`
读取同一个版本号。Rime 的 `__include` 只在方案里生效，词典头不支持，所以没法靠 yaml 本身共用一份。

## 测试

测试位于 `spec/*.test.yaml`，由 [mira](https://github.com/rimeinn/mira) 运行。日常用
`scripts/test.ts`，五个方案并行，全部跑完约 40 秒；失败时只打印失败用例，完整输出留在它给出的
临时目录里：

```sh
bun scripts/test.ts                  # 全部五个方案
bun scripts/test.ts yipin qingyun    # 只跑指定方案，snow_ 前缀可省
```

它为每个方案准备一份独立环境，这几步都是为了提速或者能并行，不要省掉：

- **精简的源目录**：mira 的每个 deploy 都会把整个 `source_dir`（spec 里写的是 `..`，也就是
  整个仓库，带 `.git`、`node_modules`、`cache`，约 1 GB）复制一遍。脚本只复制
  `git ls-files -co --exclude-standard` 列出的文件，再加上 `rime-stroke/stroke*`，相当于 CI 的
  全新 checkout。本机的 `*.userdb`、`user.yaml` 自然被排除在外，不用再 `rm -rf *.userdb`。
- **`default.custom.yaml` 只留被测方案**：否则每个 deploy 都要检查 `schema_list` 里的全部五个
  方案。这两项加起来，每个 deploy 从约 4 秒降到约 1.4 秒。
- **独立的 `TMPDIR`**：mira 的工作目录写死为 `$TMPDIR/mira`，启动时整个删掉，两个 mira
  同时跑会互相删目录然后崩溃。
- **独立的缓存副本**：`-C` 指向的 staging 目录不能共用。带 `patch` 的 deploy（sanpin、
  jiandao 的 `sentence`，sipin 的 `special`）会把改过的方案编译进缓存，改了词典后几个进程还会
  同时重建同一份 `.bin`。脚本先把仓库的 `cache/` 复制给每个方案，跑完再把更新过的文件写回去。

只调一个 deploy 时直接用 mira 的 `-R` 更快，但这会用仓库本身作 `source_dir`，所以要自己清
词频，同时也不能有别的 mira 在跑：

```sh
cp rime-stroke/stroke* .          # 笔画反查依赖
rm -rf *.userdb                   # 清掉上次运行累积的词频，与 CI 的全新 checkout 对齐
mira -C cache -R '^popping$' spec/snow_sipin.test.yaml
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

- `lua_processor@*snow.statistics*processor` 排在 processors **第一位**，只观察按键，除了并击
  的最后一次松开（见「并击」）都返回 `kNoop`。它把每个计入的键追加到 `env.steps`，在每次上屏时结算写库。排第一是因为
  `ascii_composer` 会吃掉临时西文下的按键（要靠它们判断临时西文是否上屏了），`shape_processor`、
  `select_character` 等也会 `kAccepted` 掉按键，排在它们后面就看不到这些键了。
- `lua_translator@*snow.statistics*translator` 紧跟在 `datetime` 后面，处理 `otj` / `otjq` /
  `otjs`，以及 `tj` 前加 `r` / `z` / `y` / `n` / `q` 只看一个时段的 `ortj`、`oqtjs` 等。如果排在 `calculator` 后面，首选会被计算器回显的 `tj` 抢走。
- 接入的方案：sipin、sanpin、yipin、jiandao、qingyun。命令前缀取自 `lua/input`，和
  datetime、number、calculator 共用：多数方案是 `o`。yipin 的 `o` 会被 `combo_popping` 吞掉，
  所以改用 `i`，和符号一致（`itj` 等没有和符号码重复）；命令由 `chord_composer/algebra` 里的右手并击
  `jkl` / `jkl;` / `uio` 打出，结果加方括号，以免被 `output_format` 当成非法音节删掉。
  qingyun 的 `o` 是普通编码，所以用两个着重号
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
  - 有效按键结算出来不是正数的上屏整次丢掉，不写负增量；
  - 极速窗口的字数、时长只在速度更高时一起覆盖。这两个字段不一定各自递增（速度更高的窗口可能
    字数更少），合并时各取最大值，结果可能拼自两个窗口。窗口时长都在一分钟上下，偏差很小，接受。
  - 两台设备的 `installation_id` 相同时，它们的数据会按最大值互相覆盖，这是这种方案的前提。
- 日期取结算（上屏）那一刻的本地日期。

### 哪些按键计入（`processor.func`）

1. `snow.redispatching` 为真时跳过：popping 用 `engine:process_key()` 把同一个键重投到链顶，
   第一次已经记过了。
2. `ascii_mode` 为真时跳过，包括全局英文和临时西文：它们不属于中文输入。临时西文下作为西文
   上屏时要清空之前的按键，见第 6 条。
3. 并击方案先按下一节的规则处理并击键。
4. 所有 release 事件和修饰键（`0xffe1`–`0xffee`）本身都跳过。修饰键和别的键一起按时，整组只算
   在那个键上；单独按放的修饰键（如切换临时西文的 Shift）不算。
5. 有编码时，其余按下的键全部计入，包括 Ctrl/Alt 组合键（整组算一个）、退格、方向键、Escape、
   空格、选重键。没有编码时，只计入 `0x21`–`0x7e` 的可见字符，并且要求没有按 Ctrl/Alt/Super，
   也就是只算会开始一段输入、或会直接上屏的键；快捷键属于应用，不算。单独输入的空格、回车、Tab
   等空白符只是排版，也不算中文输入，按键和上屏都不记（回车、Tab 本来就在范围外，空格靠
   `unhandled_key_notifier` 的回调另外排除）。
6. 编码**全部**清空而中间没有上屏，就认为用户放弃了这段输入，`env.steps` 整个清空，连同清空
   编码的那个键都不计：Escape、退格删光、key_binder 把 `Control+g`、`Control+bracketleft` 转成的
   Escape、别的组件 `ctx:clear()` 都算。检测不针对具体的键，而是比较前后两个事件：processor 排在
   第一位，所以事件开始时看到的就是上一个事件处理完的状态。每个事件（跳过的合成键除外，含
   release、`ascii_mode` 下的键）开始时，如果 `env.composing`（上一个事件开始时有编码）为真、现在
   没有编码、`env.committed`（期间 `commit_notifier` 或 `commit_text` 上屏过）为假，就清空，然后
   把这两个字段换成当前的值。这样不用在按下时判断这个键会不会清空编码：Escape 在有已确认的段时只清
   最后一段（`ClearPreviousSegment`），而且最晚到这个键自己的松开事件就会结算。顶屏时编码也会
   短暂清空，但有上屏，handover 留下的键不受影响。

   临时西文同理：它会把已经打的中文编码换成对应的字母一起上屏，这次上屏不记，进入临时西文之前
   打的中文编码也不计，也就是清空 `env.steps`。上屏有两条路径，都要处理：
   - 本机改过的 librime（`~/Public/librime`）里，空格、回车、改动过西文后切回中文等都由
     ascii_composer 调用 `engine:CommitText`，不经过 `commit_notifier`，也就是编码没了而没有
     上屏，上面的规则正好清空 `steps`；
   - 原版 librime（mira 用的是 Homebrew 的 1.17）里，回车走 express_editor 的
     `context:commit()`，这时 `ascii_mode` 还开着，所以 `commit_notifier` 的回调里遇到
     `ascii_mode` 也清空 `steps`、不记。

   没改动就切回中文时，ascii_composer 会还原中文编码，`steps` 保留，接着累计。

每个计入的键 $k$ 记两个量：

$$
e_k=\begin{cases}-1 & k\text{ 是退格}\\ +1 & \text{其他}\end{cases}
\qquad
\delta_k=\begin{cases}t_k-t_{k-1} & t_k-t_{k-1}<T_\text{idle}\\ 0 & \text{其他}\end{cases}
$$

其中 $t$ 取自 `rime_api.get_time_ms()`，是单调时钟的毫秒数（不是墙上时间，只能用来算间隔）。
$t_{k-1}$ 是上一个计入的键的时刻，$T_\text{idle}=5000$ ms。停顿之后的第一个键 $\delta=0$。

### 并击（yipin）

方案配置里有 `chord_composer/alphabet` 时，processor 按旧版 `ChordComposer`
（`librime/src/rime/gear/chord_composer.cc`）的规则跟踪并击，**一组并击算一个键**：

- chord_composer 吃掉并击键的按下和松开。所有键都松开时，它把并击序列化、过 `algebra` 和
  `output_format`，再把结果**逐个字符用 `ProcessSyntheticKey` 从链顶重投**（`bay`、`iduh `、
  `od ` 之类），没人处理的合成键由它直接 `CommitText`。合成键在 Lua 里和真实按键一样，都是
  字母的按下事件，没有标志可区分。
- processor 用 `env.held` 镜像 chord_composer 的 `pressed_keys`：不在 `ascii_mode` 时，按下
  alphabet 里的键（无修饰键）只记进 `held`，不计数；非并击键或带修饰键的事件（按下、松开都算）
  清空 `held`，这和 C++ 里 `state_.Clear()` 的条件一致，键本身照普通按键处理。
- 让 `held` 变空的那次松开，就是 chord_composer 要 FinishChord 的时刻。processor 先记一个键，
  然后置 `env.finishing`，**自己调用 `engine:process_key()` 把这次松开交给后面的处理器**，
  返回后清掉 `finishing` 并返回 `kAccepted`。嵌套调用期间到达的事件都是合成键，一律跳过；
  `process_key` 是同步的，所以界限是精确的，不依赖计时。这个键必须**在重投之前**记下，因为重投
  中途就会上屏。
- 合成按键数为 0（`output_format` 把组合 erase 掉了）的并击照样计入 `keys`，但 $e=0$：它没有
  打出任何东西，也不需要退格。
- 空格也是并击键，没有编码时单按空格，chord_composer 合成的空格没人处理，由
  `unhandled_key_notifier` 看到。这时回调置 `env.blank`，重投返回后把这组并击从 `env.steps`
  里删掉，和非并击方案一样整个不记。删之前要确认它仍是最后一个：合成按键里如果先有别的上屏，
  它已经被结算走了。
- `combo_popping` 是在下一组并击的第一个合成字母上顶屏的，这时那组并击已经记进 `env.steps`，
  所以它的两处上屏都要设 `snow.handover = 1`。
- yipin 的退格绑定为 `back_syllable`，一次删一个音节，即一组并击，$e=-1$ 的口径不用改。
- 时长 $\delta$ 取相邻两次结算并击（以及普通按键）之间的间隔。
- 没处理 `use_shift` 等选项（开了之后要像 C++ 那样换算到基础层），冰雪一拼没有开。

### 上屏从哪里来

| 来源 | 捕获方式 | 记作的上屏文字 |
| --- | --- | --- |
| `context:commit()`：选词、空格、顶屏、回车上屏编码、标点 | `commit_notifier` | `get_commit_text()` |
| 没有编码时直接放行给应用的可见字符（数字、标点等，不含空格），以及 chord_composer 因为没人处理而直接上屏的合成键 | `unhandled_key_notifier` | 这个字符 |
| `snow.commit_text`：以词定字、略码、英拼的空格 | `property_update_notifier`，属性名 `commit_text` | 属性值，即 `counted` 参数，默认为上屏的文字 |

- `engine:commit_text` 不触发 `commit_notifier`。**以后新写的直接上屏一律调用
  `snow.commit_text`**，否则这次上屏的字数会漏记，它的按键也会被算进下一次上屏。
- 一个键触发几次上屏时，要让统计只记成一个词加上这个键打出的部分，否则后几次分不到按键。
  略码就是这样做的：重复出来的部分不管接在词前还是词后，都合成一次上屏，词前的部分上屏时
  `counted` 传空串不记，词后的部分上屏时 `counted` 传两部分之和；词本身用 handover 把略码键
  转给重复出来的部分。
- `unhandled_key_notifier` 对 `kRejected` 的键也会触发，所以回调里要排除 `ascii_mode`；还要
  排除 `snow.redispatching`，因为顶屏后重投、最终没人处理的键（比如空格）并没有到达应用。
- **屏蔽**：`commit_notifier` 的回调里，如果 `context.input` 是统计命令（和翻译器共用
  `parse_command`，不用另配），或者与方案 `statistics/exclude` 列表里任一个正则**完全匹配**
  （`regex_match`），这次上屏不记。它的按键照常按 handover 用 `take` 从 `env.steps` 里取出后
  丢掉，顶屏键仍留给下一个词。只作用于这一条路径：另外两条上屏时 `input` 要么为空，要么取决于
  调用方有没有先清空，按 `input` 判断没有意义。

### 按键归到哪次上屏

设第 $j$ 次上屏的文字为 $c_j$，结算时 `env.steps` 里有 $n_j$ 个键。从末尾往回累加 $e_k$，
累加到 $h_j$ 为止，这一段留给下一次上屏，其余的键组成集合 $K_j$。$h_j=0$ 时全部结算。

$h_j$ 就是 `snow.handover`，单位是有效按键：popping 按规则顶屏时取 $1+\ell$，$\ell$ 是因
`rule.prefix` 被推回输入框的编码长度；combo_popping 顶屏时取 $1$（那组并击）；略码先上屏原词
时取 $1$（略码键，算作重复出来的部分的编码，如 `wgA` 记成「这个」2 码、重复的「这个」1 码）；
其他上屏都取 $0$。

按有效按键数而不是按键数往回数，是为了让推回的编码中途回改过时也能分对：`abcx⌫d` 后按
`e` 顶屏、推回 `cd`，往回数 3 个有效按键得到 `cx⌫de`，「ab」记 2 码。只要每个 $e=+1$ 的键都
往输入框里加了一个字符、每个退格都删了一个字符，分界就是精确的：从末尾累加到 $h_j$ 的位置，
是输入框长度最后一次等于 $|\text{input}|-\ell$ 的时刻（$|\text{input}|$ 取顶屏前），此后
前面的编码再没被动过。

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
| `keys` 按键 | $\sum_j \lvert K_j\rvert$ |
| `duration` 时长（ms） | $\sum_j\sum_{k\in K_j}\delta_k$ |
| `window_chars`、`window_duration` 极速窗口 | 见下 |
| `word<i>` 词长分布 | $\#\{j:\lvert c_j\rvert=i\}$ |
| `code<i>` 码长分布 | $\#\{j:E_j=i\}$，$i\ge 1$，$E_j$ 见下 |

词数、字数和有效按键不单独存，显示时由分布算出：

$$
\text{words}=\sum_i\text{word}_i=\sum_i\text{code}_i,\qquad
\text{chars}=\sum_i i\cdot\text{word}_i,\qquad
\text{effective\_keys}=\sum_i i\cdot\text{code}_i
$$

为此**档位不设上限**，「十及以上」只在显示时合并。

**有效按键**：

$$
E_j=\sum_{k\in K_j}e_k
$$

有编码时每按一次退格，它本身让按键加 1、有效按键减 1，被删掉的那个键之前也给两边
各加过 1，所以两者的差值增加 2。有效按键近似于「不打错时需要的按键数」。

按键归属正确时每次上屏至少有一个有效按键，$E_j\ge 1$。$E_j\le 0$ 说明归属出了偏差（见
「已知局限」），这次上屏整次丢掉：不写 `keys`、`duration`、`word`、`code`，$K_j$ 照样从
`env.steps` 里移除。所以库里不会有 `word0`、`code0`；报告解析字段时也只认正整数的档位。

**码长按有效按键算，而不是按 `ctx.input` 的长度算**：`input` 不含辅助码（sipin 的辅助码存在
`shape_input` 属性里）、选重键和上屏键，没法和按键数对上。

**两个不变式**：每次结算 `word`、`code` 各加一档，所以 $\sum_i\text{word}_i=\sum_i\text{code}_i$；
$E_j\le\lvert K_j\rvert$，所以 $\sum_i i\cdot\text{code}_i\le\text{keys}$。
以后改口径时，用这两条来检查，另外库里不应出现 `word0`、`code0`。

**极速**：在当前会话（engine 实例）内，把连续若干次上屏的字数和时长累加成一个窗口，
时长 $D_W\ge 60\,\text{s}$ 时结算 $v=\text{chars}_W/D_W$，只有比当天已记录的窗口快才把
$\text{chars}_W$、$D_W$ 一起写进 `window_chars`、`window_duration`，然后清空窗口重新累计。
存窗口而不存速度，是因为 `c=` 只能存整数。窗口不滑动，所以它不是严格的「最快一分钟」，而是
「某段至少一分钟的输入的平均速度」的最大值。

库里的窗口不是报告里的极速。会话末尾没满一分钟的窗口不结算（见「已知局限」），只用库里的窗口的话，
极速可能低于均速：快的那段正好落在没结算的尾巴里，或者一天的输入不满一分钟、一个窗口都没有。
所以报告在时段的总时长 $D\ge 60\,\text{s}$ 时取

$$
\text{极速}=\max\left(\frac{60000\cdot\text{window\_chars}}{\text{window\_duration}},\ \text{均速}\right)
$$

整个时段本身就是「一段至少一分钟的输入」，它的平均速度就是均速，按定义也是候选；$D<60\,\text{s}$ 时
不存在满一分钟的段，报告里省略极速这一项。这个最大值只在显示时取，库里仍只存原始窗口；周、月、年、
累计对合计的数据套用同一条规则，所以任何时段都有 均速 ≤ 极速。

### 报告

每个时段一个候选，文字按行排：

1. 📊 加日期范围加「统计数据」：今日「2026 年 10 月 10 日」，本周「2026 年 41 周」（ISO 8601
   周数，年和周数都按本周的周四算，所以 1 月初可能显示为上一年的 52 或 53 周；不用 `os.date` 的
   `%G`、`%V`，Windows 上的 Lua 不支持），本月「2026 年 10 月」，本年「2026 年」，累计
   「截至 2026 年 10 月 10 日累计」；
2. ⌨️ 加「方案：」接方案名和 id；
3. 💻 加「平台：」接 `distribution_code_name` 加版本（fcitx5-rime 的 `distribution_name` 只是 Rime，
   所以不用它）。`tjq` 改为「设备：全部」，`tjs` 改为「设备：<installation_id>」，本机再加「（本机）」——
   其他设备的平台库里没有记；
4. 分割线（14 个 `─`）；
5. 正文：词、字、用时；键、有效键、键准；均速、极速、击键；码长、理论码长；平均词长、多字词占比；分割线；词长分布；
   码长分布。时长不满 60 秒时省略极速。没有上屏时正文只有前三行。所有比值都经 `ratio` 计算，分母为 0 时记为 0，所以时长为 0 时
   均速、击键显示 0，而不是 inf 或 nan；词长、码长分布的各档用顿号隔开；
6. 分割线；
7. 署名「❄️ 冰雪统计 v0.3.11」，版本号取自 `snow.version`。

**正文每行不超过 16 个全宽字符**（汉字、全角标点算 1，ASCII 字母数字和空格算半个），候选框
才不会被撑得太宽。数值一行两项是按七八位数估过的。以后往报告里加项时也要守住这个宽度；开头三行、
两行分布和署名不受限制。

记 $D$ 为 `duration`，单位 ms：

$$
\text{均速}=\frac{60000\cdot\text{chars}}{D}\ \text{字/分},\quad
\text{击键}=\frac{1000\cdot\text{keys}}{D}\ \text{键/秒},\quad
\text{码长}=\frac{\text{keys}}{\text{chars}},\quad
\text{键准}=\frac{\text{effective\_keys}}{\text{keys}},\quad
\text{理论码长}=\frac{\text{effective\_keys}}{\text{chars}},\quad
\text{平均词长}=\frac{\text{chars}}{\text{words}},\quad
\text{多字词占比}=1-\frac{\text{word}_1}{\text{chars}}
$$

- 分布显示的是各档占上屏次数的比例，长度用 `number.lua` 的 `chinese` 写成中文数字，十及以上合为一档。
- 周、月、年、累计把各天的计数相加，极速先取各天、各安装中最快的那个窗口，再和合计的均速取最大值；本周从周一算起，累计是该方案的全部日期。
- `otjq` 把各安装的计数相加；`otjs` 列出所选时段中最长的那个（不带字母时即累计）里有数据的安装。
- 报告只看当前方案。不单独做导出：Rime 同步时会把整个库导出为同步目录下的
  `snow_statistics.userdb.txt`，包含全部方案、全部安装的逐日原始计数。

### 其他取舍

- 方案之间码长不可比，所以按方案分开统计；设备之间速度不可比（电脑和手机），所以按安装分开统计。
- 时长不计超过 5 秒的停顿，衡量的是打字本身，不是想内容的时间。
- 不记录上屏的文字本身：一是出于隐私，二是旧脚本那种「生字本」的判定（距上次上屏超过 3 秒）
  主要是噪声。

### 已知局限

- 缓冲模式下的顶屏只 confirm 不上屏，handover 不起作用；缓冲区整体上屏时，按键都算在那一次上。
- handover 假设推回的编码里每个 $e=+1$ 的键都往 `input` 里加了一个字符。推回的那段里如果有
  不进 `input` 的键（有编码时的方向键、sipin 存进 `shape_input` 的辅助码），分界会偏，上一次
  上屏多记几码，下一次少记；删掉推回的编码时下一次的 $E_j$ 还可能不是正数，被整次丢掉。
- 极速窗口不跨会话：切换方案或重启输入法时，没满一分钟的窗口会被丢掉；跨零点的窗口记在
  结算那天。报告里极速和均速取最大值，不会因此低于均速，但丢掉的那段如果比均速和所有窗口都快，
  也找不回来。
- 并击状态是镜像的。如果和 C++ 不同步，嵌套的 `process_key` 可能返回 false，这时外层仍返回
  `kAccepted`：返回 `kRejected` 会让 `unhandled_key_notifier` 触发第二次，代价只是这次松开不会再
  交给应用。
- 辅助码并击（`v…v`）和它所属的音节是两组并击，但 `back_syllable` 未必按这个粒度删，退格后的
  有效按键会有偏差。
- 只适用于旧版 `chord_composer`。yipin 如果改用 `streaming_chord`（`StreamingChordProcessor`），
  这套逻辑要重写：流式并击直接 `PushInput`，靠超时切分音节，不一定等所有键松开，只有双功能键
  会用合成键重投。

### 验证方法

spec 里**没有**统计的用例（mira 的按键都是瞬间完成的，时长和速度没有意义，报告格式又常改）。
改动统计逻辑后，用临时用例混合各种上屏方式，再检查两个恒等式。临时用例
直接用 mira 跑（`test.ts` 跑完会删掉临时目录）。mira 的数据目录是 `$TMPDIR/mira/data/`，
**每个 deploy 都会重建**，所以临时用例只写一个 deploy。跑完后
在数据目录里用 `rime_dict_manager -b` 把库导出成同步快照，逐个「方案 × 日期 × 安装」检查两个不变式：

```sh
cd "$TMPDIR/mira/data" && rime_dict_manager -b snow_statistics >/dev/null
cat sync/*/snow_statistics.userdb.txt | python3 -c '
import re, sys, collections
rows = collections.defaultdict(dict)
for line in sys.stdin:
    if line.startswith("#"):
        continue
    key, field, value = line.rstrip("\n").split("\t")
    rows[key][field] = int(re.match(r"c=(-?\d+)", value).group(1))
for key, r in rows.items():
    f = lambda kind, w: sum(w(int(k[len(kind):])) * v for k, v in r.items() if re.fullmatch(kind + r"\d+", k))
    assert f("word", lambda i: 1) == f("code", lambda i: 1), (key, r)
    assert f("code", lambda i: i) <= r.get("keys", 0), (key, r)
'
```

要追踪每个键、每次结算，就临时在 `processor.func` / `record` 里用 `io.open(..., "a")` 写一个
文件。`log.error` 和 stderr 在 mira 的输出里都看不到。

## lua 编码规范

`lua/snow/` 下自写的组件统一按以下写法；`calculator.lua` 的函数库部分是外来代码，不强求。

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

**类型检查**

`lua/snow/` 下自写的文件应当没有 lua-language-server 警告（编辑器里按 strict 级别检查，含
`no-unknown`）。VS Code 只分析打开过的文件，要一次查全用扩展自带的命令行：

```sh
echo '{"diagnostics.groupFileStatus":{"strict":"Any","strong":"Any"},"diagnostics.disable":["lowercase-global"]}' > "$TMPDIR/luarc.json"
~/.vscode/extensions/sumneko.lua-*/server/bin/lua-language-server --check="$PWD" \
  --configpath="$TMPDIR/luarc.json" --checklevel=Warning --logpath="$TMPDIR/luals" --check_format=json
```

末行给出总数，逐条结果在 `$TMPDIR/luals/check.json`。容易触发警告的几种写法：

- `snow.get_db` 在库被别的进程锁住时返回 `nil`，所以持有它的字段要标 `LevelDb|nil`，用之前判空。
- 下标从 0 开始的表（如 `number.lua` 的 `digits`）标 `table<integer, string>`，不要标
  `string[]`：后者用 `[0]` 取值推不出类型。索引它的键也必须是 integer，`tonumber()` 返回
  `number?`，不行，数字字符可以用 `s:byte(i) - 48`。
- 用字面量建的、以字符串为键的查找表（如 `{ a = "j", e = "q" }`）用变量去索引时推不出类型，
  要标 `---@type table<string, string>`。函数里先建空表再逐项填的局部变量同理，要标元素类型。
- 一个 `if` 的某个分支给变量赋字面量（`x = ""`），另一个分支写 `x = x:sub(1, -2)`，后者会
  报 `no-unknown`，加 `---@type` 也没用（LuaLS 的问题）。改成一个表达式
  `x = cond and "" or x:sub(1, -2)`。

## processors 顺序

五个顶功方案（sipin / sanpin / yipin / jiandao / qingyun）共用一套相对顺序，新增或移动
处理器时按下表对齐：

```yaml
  processors:
    - lua_processor@*snow.statistics*processor
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
- `statistics` 排第一：它只计数，除并击的最后一次松开外都返回 `kNoop`，要在其他处理器吃掉按键之前看到每个键，
  包括被 `ascii_composer` 吃掉的临时西文按键（靠它们判断临时西文是否上屏，以便丢掉之前累计的按键）。
  全局英文和临时西文由它自己按 `ascii_mode` 跳过；popping 重投的那一次靠 `snow.redispatching` 去重。
- 其余沿用 Rime 原生顺序。

拿不准的那一对不要按多数方案的现状定，跑 mira。另外，某个功能用小写键测像是完全
失效时，可能是靠大写回投在工作（如 qingyun 的 editor），要连大写一起测。

### 验证

改动 processors 后跑全部五份 spec：

```sh
bun scripts/test.ts
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
    - lua_translator@*snow.datetime       # yipin 无
    - lua_translator@*snow.statistics*translator
    - lua_translator@*snow.number         # 以下 yipin 均无
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
