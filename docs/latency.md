# 按键反馈延迟

[`scripts/benchmark-latency.ts`](../scripts/benchmark-latency.ts) 使用带 librime-lua 的 `rime_api_console` 逐键测量反馈延迟。用例在 [`scripts/data/latency-cases.ts`](../scripts/data/latency-cases.ts)，按各方案教程和功能 spec 取码，覆盖词语查询、部件反查、补码、翻页、退格、顶屏、缓冲造词及连续输入；冰雪一拼发送完整的按下和松开事件。首轮校验指定候选或上屏结果。

## 运行

依赖 Bun、`scripts/` 的依赖、已初始化的 `deps/rime-radical-pinyin` 子模块、带 librime-lua 的 `rime_api_console` 和含 `essay.txt` 的 Rime 共享数据目录。控制台默认从 PATH 查找，共享数据自动尝试鼠须管及 Linux 的常见安装目录；可用 `--console`、`--shared-data` 显式指定。独立环境会复制部件反查方案和词典；`--ref` 按历史版本锁定的子模块提交取文件。

```sh
# 五个方案，每个场景默认 30 轮
bun scripts/benchmark-latency.ts

# 完整发布检查：五方案全部场景，至少 200 轮，统一预算
bun scripts/benchmark-latency.ts --ci

# 指定方案、场景、轮数及重复事件的 p99 预算
bun scripts/benchmark-latency.ts jiandao --case '^dense-prefix$' --rounds 200 --max-p99-ms 50

# 功能测试通过后自动串行测量，并更新下方结果；可指定方案
bun scripts/test.ts
```

方案参数可省略 `snow_` 前缀；`--case` 接受场景名正则。`--output-dir` 指定输出目录，默认是调用目录下的 `output/latency/`，同名文件会覆盖。`--ref` 可指定 Git 引用，使用该引用的方案、Lua 和词典，驱动与用例仍使用当前代码。`bun scripts/test.ts [方案]` 默认先跑功能测试，全部通过后再测对应方案的性能并更新当前结果；旧的 `--latency` 参数仍兼容，无须添加。

输出包含逐事件反馈与耗时 `samples.jsonl`、环境与分组统计 `report.json`，以及各方案控制台日志。统计按方案、场景、事件位置、按键类型及首轮／重复轮分组，记录 p50/p95/p99、最大值和超过 16/50/100 ms 的次数。超时、Rime 错误、首轮结果不符或显式预算超限时返回失败；预算超限会先保存报告，检查范围为各重复场景、事件及按键类型。

## 测量口径

控制台常驻，每次只发送一个按键事件，收到完整反馈后再发下一键。计时从写入 stdin 开始，到当前候选页输出后的只读 `print schema list` 屏障返回结束，涵盖候选惰性生成、管道通信、控制台序列化及驱动解析，不含界面绘制及键盘硬件耗时；部署、结果断言和驱动日志落盘在计时之外。每个方案另测 100 次空请求作为通信开销参考，不从样本中扣除。

启动时冻结源码，五方案串行测量，每个场景使用独立临时目录、编译数据副本和空用户词典，不使用本机补丁、用户词典或编译缓存。同一场景各轮共享用户词典，上屏会学习；首轮 `first` 与后续 `repeat` 分开统计。首轮不是清空系统页缓存后的冷启动。测量时避免同时运行 mira、其他基准或网站构建。

分位数使用 nearest rank。常规 30 轮时，同一事件有 29 个重复样本，其 p99 接近最大值；发布检查至少 200 轮，每个事件位置至少有 199 个重复样本。

## 统一发布预算

五个方案采用 [`latency-budget.ts`](../scripts/lib/latency-budget.ts) 中的 `LATENCY_BUDGET`，有效反馈的 P50 < 10 ms、P95 < 25 ms、P99 < 50 ms。50 ms 上限参考 [RAIL 的输入处理预算](https://web.dev/articles/rail#response_process_events_in_under_50ms)，为排队和前端绘制留出余量；10/25 ms 是本仓库为连续输入设置的更严格工程目标，不能据此保证所有设备的端到端延迟。

`--ci` 固定测当前工作区、全部方案和全部场景，至少 200 轮。统计 `feedback` 分组：顺序方案计全部事件，冰雪一拼计并击末次松开及翻页等非并击操作。每方案的重复反馈须同时满足三项分位数；每场景、每个按键位置另须 P99 < 50 ms，防止汇总掩盖局部卡顿；首次遍历最大反馈须 < 100 ms。没有按方案放宽预算、删除离群值或自动重跑择优。保存的报告可用 `bun scripts/check-latency.ts <report.json>` 复查。

[`latency.yml`](../.github/workflows/latency.yml) 在 Ubuntu 24.04 上构建固定版本 librime 1.17.0 与 librime-lua，使用 Bun 1.3.14 和 librime 自带的 `essay.txt` 串行测量，上传报告与日志。push、pull request 和发布共用该工作流；[`release.yml`](../.github/workflows/release.yml) 的发布 job 通过 `needs: [latency]` 依赖性能门禁，检查失败或缺失时不能执行打包、创建发布及上传。

## 当前结果

<!-- latency-results:start -->
每行记录该方案最近一次完整场景采样，自动更新；数值取第 2 轮起的有效反馈，单位为毫秒。分方案测试保留其他方案各自的结果与测量环境。

| 方案 | 轮数 | 样本数 | p50 | p95 | p99 | 最大值 |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 冰雪四拼 | 30 | 2,668 | 2.07 | 4.36 | 6.61 | 12.86 |
| 冰雪三拼 | 30 | 2,784 | 2.24 | 3.45 | 5.17 | 6.37 |
| 冰雪一拼 | 30 | 928 | 2.07 | 3.38 | 4.54 | 4.83 |
| 冰雪键道 | 30 | 3,190 | 2.82 | 5.76 | 6.41 | 8.74 |
| 冰雪清韵 | 30 | 3,132 | 4.61 | 7.26 | 12.02 | 19.33 |

| 方案 | 报告时间（北京时间） | 环境 | Rime | 源码快照 |
| --- | --- | --- | --- | --- |
| 冰雪四拼 | 2026-11-02 21:52:03 | darwin/arm64 · Apple M2 Max | 1.17.0 | `46ceed7093b6` |
| 冰雪三拼 | 2026-11-02 21:52:03 | darwin/arm64 · Apple M2 Max | 1.17.0 | `46ceed7093b6` |
| 冰雪一拼 | 2026-11-02 21:52:03 | darwin/arm64 · Apple M2 Max | 1.17.0 | `46ceed7093b6` |
| 冰雪键道 | 2026-11-02 21:52:03 | darwin/arm64 · Apple M2 Max | 1.17.0 | `46ceed7093b6` |
| 冰雪清韵 | 2026-11-02 21:52:03 | darwin/arm64 · Apple M2 Max | 1.17.0 | `46ceed7093b6` |
<!-- latency-results:end -->

本节由完整场景的性能测试自动生成。常规测试为 30 轮，CI 发布检查至少 200 轮；历史版本或仅选取部分场景的探查不会替换完整结果。报告及这份文档的快照保存在本轮输出目录，CI 会一并上传。
