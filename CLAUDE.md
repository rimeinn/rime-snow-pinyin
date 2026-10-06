# 冰雪拼音开发约定

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

## lua 的两处坑

- **代理码路径必须走 `snow.prepare`，不要自己 yield。** 三拼的 `table_like.lua` 把输入改写成
  代理码（`dlkm` → `dl km`、补 `?`）再查词，librime 会把补出来的 ` ` `?` `~` 算进 quality，
  `snow.prepare` 负责把这部分虚高和 `_end` 一起修正回来。
- **`fini` 里不能读 `env.engine.schema`。** librime 切换方案时先换 `schema_` 再销毁旧组件，
  `fini` 读到的是新方案的 `schema_id`。`snow.get_db` / `release_db` 按方案名引用计数，
  名字要在 `init` 里记到 `env` 上（如 `env.user_dict_name`），`fini` 用记下的那个。
  记错名字时旧方案的 LevelDB 会一直占着 `LOCK`，表现为同步时「刚切走的那个方案」报
  `Error opening db ... already held by process`。

## processors 顺序

五个顶功方案（sipin / sanpin / yipin / jiandao / qingyun）共用一套相对顺序，新增或移动
处理器时按下表对齐：

```yaml
  processors:
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
