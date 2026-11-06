// 常驻 rime_api_console 的逐键反馈延迟；用法与测量边界见 AGENTS.md 的「按键反馈延迟」。
import { spawn, spawnSync } from "node:child_process";
import {
	appendFileSync,
	constants,
	copyFileSync,
	mkdirSync,
	mkdtempSync,
	readFileSync,
	readdirSync,
	realpathSync,
	rmSync,
	statSync,
	utimesSync,
	writeFileSync,
} from "node:fs";
import { arch, cpus, platform, release, tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { StringDecoder } from "node:string_decoder";
import { LATENCY_CASES, SCHEMA_NAMES } from "./data/latency-cases";
import { LATENCY_BUDGET, latencyBudgetFailures } from "./lib/latency-budget";
import { ROOT } from "./lib/paths";
import {
	copyRimeDependencies,
	RADICAL_SUBMODULE,
	RIME_DEPENDENCIES,
} from "./lib/rime-dependencies";

function splitKeys(sequence: string): string[] {
	const keys = sequence.match(/\{[^{}]+\}|[^{}]/g) ?? [];
	if (keys.join("") !== sequence) throw new Error(`无效按键序列：${sequence}`);
	return keys.map((key) => (key === " " ? "{space}" : key));
}

function distribution(values: number[]) {
	const sorted = values.toSorted((a, b) => a - b);
	const percentile = (p: number) =>
		sorted[Math.max(0, Math.ceil(p * sorted.length) - 1)];
	return {
		n: sorted.length,
		p50: percentile(0.5),
		p95: percentile(0.95),
		p99: percentile(0.99),
		max: sorted.at(-1),
		over16ms: sorted.filter((ms) => ms > 16).length,
		over50ms: sorted.filter((ms) => ms > 50).length,
		over100ms: sorted.filter((ms) => ms > 100).length,
	};
}

function clone(src: string, dest: string) {
	if (statSync(src).isDirectory()) {
		mkdirSync(dest, { recursive: true });
		for (const name of readdirSync(src))
			clone(join(src, name), join(dest, name));
	} else {
		mkdirSync(dirname(dest), { recursive: true });
		copyFileSync(src, dest, constants.COPYFILE_FICLONE);
		const { atime, mtime } = statSync(src);
		utimesSync(dest, atime, mtime);
	}
}

function copyRimeSource(source: string, dest: string) {
	mkdirSync(dest, { recursive: true });
	for (const name of readdirSync(source)) {
		if (/^snow_.*\.(yaml|txt)$/.test(name) && !name.endsWith(".custom.yaml"))
			clone(join(source, name), join(dest, name));
	}
	clone(join(source, "lua"), join(dest, "lua"));
	clone(join(source, "default.yaml"), join(dest, "default.yaml"));
	// 历史版本尚未依赖部件词库时保持原来的部署环境。
	if (
		readFileSync(join(source, "snow_sipin.schema.yaml"), "utf8").includes(
			"    - radical_pinyin\n",
		)
	)
		copyRimeDependencies(source, dest);
}

function sourceFingerprint(source: string): string {
	const hash = new Bun.CryptoHasher("sha256");
	const add = (file: string) => {
		const path = join(source, file);
		if (statSync(path).isDirectory()) {
			for (const name of readdirSync(path).sort()) add(join(file, name));
		} else {
			hash.update(`${file}\0`);
			hash.update(readFileSync(path));
			hash.update("\0");
		}
	};
	for (const name of readdirSync(source).sort()) {
		if (
			name === "lua" ||
			name === "default.yaml" ||
			RIME_DEPENDENCIES.includes(name) ||
			(/^snow_.*\.(yaml|txt)$/.test(name) && !name.endsWith(".custom.yaml"))
		)
			add(name);
	}
	return hash.digest("hex");
}

// 每次 request 只允许一个在途请求。print schema list 是只读屏障；它出现在完整
// print(context) 之后，且下一次 ReadLine 刷新 stdout，适用于没有行缓冲的管道。
// 不能把 ReadLine 的按键回显、status 行或第一条候选当作反馈完成。
// Rime 的 E 级日志可能已被内部回退处理，不能仅凭日志级别判定失败。
const CONSOLE_FAILURE =
	/^(?:F\d{8}|.*\[deploy\] failure|.*Error processing key sequence|.*Lua.*error)/m;

class ConsoleDriver {
	private child;
	private pending?: {
		resolve: (value: { ms: number; output: string }) => void;
		reject: (error: Error) => void;
		start: number;
		timer: ReturnType<typeof setTimeout>;
		lines: string[];
	};
	private buffer = "";
	private errors = "";
	private closed = false;
	private transcript: string[] = [];
	private done: Promise<number | null>;
	constructor(
		binary: string,
		cwd: string,
		private schema: string,
		private log: string,
	) {
		this.child = spawn(binary, [], { cwd, stdio: ["pipe", "pipe", "pipe"] });
		const decoder = new StringDecoder("utf8");
		this.child.stdout.on("data", (data: Buffer) => {
			const chunk = decoder.write(data);
			this.transcript.push(chunk);
			this.buffer += chunk;
			let end = this.buffer.indexOf("\n");
			while (end !== -1) {
				const line = this.buffer.slice(0, end);
				this.buffer = this.buffer.slice(end + 1);
				// 当前本机版有逐字符回显，上游版可能只有提示符。
				if (line === `current schema: [${this.schema}]` && this.pending) {
					const pending = this.pending;
					const ms = performance.now() - pending.start;
					clearTimeout(pending.timer);
					this.pending = undefined;
					if (CONSOLE_FAILURE.test(this.errors + pending.lines.join("\n"))) {
						pending.reject(new Error(`Rime 出错，见 ${log}`));
					} else pending.resolve({ ms, output: pending.lines.join("\n") });
				} else if (this.pending && !line.includes("\r"))
					this.pending.lines.push(line);
				end = this.buffer.indexOf("\n");
			}
		});
		this.child.stderr.on("data", (data: Buffer) => {
			const chunk = data.toString();
			this.errors += chunk;
			this.transcript.push(chunk);
		});
		this.child.on("error", (error) => this.fail(error));
		this.child.stdin.on("error", (error) => this.fail(error));
		this.done = new Promise((done) => {
			this.child.on("close", (code) => {
				this.closed = true;
				appendFileSync(this.log, this.transcript.join(""));
				this.fail(new Error(`rime_api_console 退出（${code}），见 ${log}`));
				done(code);
			});
		});
	}
	private fail(error: Error) {
		if (!this.pending) return;
		clearTimeout(this.pending.timer);
		this.pending.reject(error);
		this.pending = undefined;
	}
	request(
		lines: string[],
		timeout = 30_000,
	): Promise<{ ms: number; output: string }> {
		if (this.pending || this.closed) throw new Error("控制台状态错误");
		return new Promise((resolve, reject) => {
			this.pending = {
				resolve,
				reject,
				start: performance.now(),
				timer: setTimeout(() => {
					this.fail(new Error(`控制台超时：${JSON.stringify(lines)}`));
					this.child.kill();
				}, timeout),
				lines: [],
			};
			this.child.stdin.write(
				`${[...lines, "print schema list", ""].join("\n")}`,
			);
		});
	}
	async close() {
		if (!this.closed) this.child.stdin.end("exit\n");
		const timer = setTimeout(() => this.child.kill(), 5000);
		const code = await this.done;
		clearTimeout(timer);
		if (code !== 0) throw new Error(`控制台退出码：${code}`);
		if (CONSOLE_FAILURE.test(this.errors))
			throw new Error(`Rime 出错，见 ${this.log}`);
	}
	async kill() {
		if (this.closed) return;
		this.child.kill();
		const timer = setTimeout(() => this.child.kill("SIGKILL"), 5000);
		try {
			// close 在 stdout/stderr 排空后触发，等待它完成日志落盘再退出。
			await this.done;
		} finally {
			clearTimeout(timer);
		}
	}
}

interface Sample {
	schema: string;
	case: string;
	round: number;
	phase: string;
	index: number;
	prefix: string;
	key: string;
	kind: string;
	ms: number;
	output: string;
}

async function main() {
	const args = process.argv.slice(2);
	const names: string[] = [];
	let rounds = 30;
	let roundsGiven = false;
	let ci = false;
	let binary = "rime_api_console";
	let output = resolve("output/latency");
	let ref = "";
	let maxP99 = Number.POSITIVE_INFINITY;
	let casePattern = /./;
	for (let i = 0; i < args.length; i++) {
		const arg = args[i];
		const value = () => {
			const v = args[++i];
			if (!v || v.startsWith("--")) throw new Error(`${arg} 缺少值`);
			return v;
		};
		if (arg === "--rounds") {
			rounds = Number(value());
			roundsGiven = true;
		} else if (arg === "--ci") ci = true;
		else if (arg === "--console") binary = resolve(value());
		else if (arg === "--output-dir") output = resolve(value());
		else if (arg === "--ref") ref = value();
		else if (arg === "--case") casePattern = new RegExp(value());
		else if (arg === "--max-p99-ms") maxP99 = Number(value());
		else if (arg.startsWith("--")) throw new Error(`未知参数：${arg}`);
		else names.push(arg.startsWith("snow_") ? arg : `snow_${arg}`);
	}
	if (ci) {
		if (!roundsGiven) rounds = LATENCY_BUDGET.minimumRounds;
		if (
			rounds < LATENCY_BUDGET.minimumRounds ||
			names.length ||
			ref ||
			casePattern.source !== "."
		)
			throw new Error(
				`--ci 必须测当前五方案全部场景，至少 ${LATENCY_BUDGET.minimumRounds} 轮`,
			);
	}
	if (!Number.isInteger(rounds) || rounds < 1 || !(maxP99 > 0))
		throw new Error("rounds 必须是正整数，p99 阈值必须大于 0");
	if (Number.isFinite(maxP99) && rounds < 2)
		throw new Error("启用 p99 门槛至少需要两轮采样");
	const schemas = names.length
		? [...new Set(names)]
		: Object.keys(SCHEMA_NAMES);
	for (const schema of schemas)
		if (!LATENCY_CASES[schema]) throw new Error(`未知方案：${schema}`);
	for (const schema of schemas)
		if (
			!LATENCY_CASES[schema].some((scenario) => casePattern.test(scenario.id))
		)
			throw new Error(`${schema} 没有匹配的场景`);
	const found = Bun.which(binary);
	if (!found)
		throw new Error(`找不到 ${binary}；需要带 librime-lua 的 rime_api_console`);
	binary = realpathSync(found);
	mkdirSync(output, { recursive: true });
	const base = mkdtempSync(join(tmpdir(), "snow-latency-"));
	const source = join(base, "source");
	let driver: ConsoleDriver | undefined;
	const git = (...args: string[]) => {
		const result = spawnSync("git", args, { cwd: ROOT, encoding: "utf8" });
		if (result.status !== 0) throw new Error(result.stderr);
		return result.stdout.trim();
	};
	try {
		const revision = git("rev-parse", ref || "HEAD");
		const dirty = ref ? "" : git("status", "--short");
		if (ref) {
			mkdirSync(source);
			const archive = spawnSync("git", ["archive", "--format=tar", ref], {
				cwd: ROOT,
				maxBuffer: 512 * 1024 * 1024,
			});
			if (archive.status !== 0) throw new Error(archive.stderr.toString());
			const extracted = spawnSync("tar", ["-xf", "-", "-C", source], {
				input: archive.stdout,
			});
			if (extracted.status !== 0) throw new Error(extracted.stderr.toString());
			// git archive 不包含子模块内容，按被测版本锁定的提交取出依赖。
			const moduleEntry =
				git("ls-tree", ref, RADICAL_SUBMODULE) ||
				git("ls-tree", ref, "rime-radical-pinyin");
			if (moduleEntry) {
				const commit = moduleEntry.split(/\s+/)[2];
				const dependency = spawnSync(
					"git",
					[
						"-C",
						join(ROOT, RADICAL_SUBMODULE),
						"archive",
						commit,
						...RIME_DEPENDENCIES,
					],
					{ maxBuffer: 32 * 1024 * 1024 },
				);
				if (dependency.status !== 0)
					throw new Error(dependency.stderr.toString());
				const unpacked = spawnSync("tar", ["-xf", "-", "-C", source], {
					input: dependency.stdout,
				});
				if (unpacked.status !== 0) throw new Error(unpacked.stderr.toString());
			}
		} else copyRimeSource(ROOT, source);
		const sourceSha256 = sourceFingerprint(source);
		const samples: Sample[] = [];
		const controls: Record<string, number[]> = {};
		const rimeVersions: Record<string, string | undefined> = {};
		const raw = join(output, "samples.jsonl");
		writeFileSync(raw, "");
		for (const schema of schemas) {
			console.log(`${SCHEMA_NAMES[schema]}：部署独立环境……`);
			const dir = join(base, schema);
			mkdirSync(dir);
			copyRimeSource(source, dir);
			writeFileSync(
				join(dir, "default.custom.yaml"),
				`patch:\n  schema_list:\n    - schema: ${schema}\n    - schema: snow_bushou\n`,
			);
			const log = join(output, `${schema}.log`);
			writeFileSync(log, "");
			driver = new ConsoleDriver(binary, dir, schema, log);
			await driver.request([`select schema ${schema}`], 180_000);
			rimeVersions[schema] = readFileSync(
				join(dir, "installation.yaml"),
				"utf8",
			).match(/rime_version: "?([^"\n]+)/)?.[1];
			controls[schema] = [];
			for (let i = 0; i < 100; i++)
				controls[schema].push((await driver.request([])).ms);
			await driver.close();
			driver = undefined;
			for (const scenario of LATENCY_CASES[schema].filter((scenario) =>
				casePattern.test(scenario.id),
			)) {
				// 每个场景独立词频，复用本方案刚编译的只读数据副本。
				const caseDir = join(base, `${schema}-${scenario.id}`);
				mkdirSync(caseDir);
				for (const name of readdirSync(dir)) {
					if (
						name.endsWith(".userdb") ||
						["user.yaml", "installation.yaml", "sync"].includes(name)
					)
						continue;
					clone(join(dir, name), join(caseDir, name));
				}
				driver = new ConsoleDriver(binary, caseDir, schema, log);
				await driver.request([`select schema ${schema}`], 180_000);
				for (let round = 0; round < rounds; round++) {
					await driver.request([
						"{Escape}",
						"set option !ascii_mode",
						"set option !buffered",
						"set option popping",
						...(scenario.options ?? []).map((option) => `set option ${option}`),
					]);
					const keys = splitKeys(scenario.keys);
					let commit = "";
					let last = "";
					for (let index = 0; index < keys.length; index++) {
						const key = keys[index];
						const result = await driver.request([key]);
						last = result.output;
						commit += [...last.matchAll(/^commit: (.*)$/gm)]
							.map((match) => match[1])
							.join("");
						const sample: Sample = {
							schema,
							case: scenario.id,
							round,
							phase: round === 0 ? "first" : "repeat",
							index,
							prefix: keys.slice(0, index).join(""),
							key,
							kind: key.startsWith("{Release+")
								? keys[index + 1]?.startsWith("{Release+")
									? "release"
									: "chord-feedback"
								: key.startsWith("{")
									? "control"
									: /^[A-Z:<>?]$/.test(key)
										? "uppercase"
										: "press",
							ms: result.ms,
							output: last,
						};
						// 写文件与解析断言发生在计时结束后。
						samples.push(sample);
						appendFileSync(raw, `${JSON.stringify(sample)}\n`);
					}
					if (round === 0) {
						const page = [
							...last.matchAll(/^\d+\. (?:\[([^\]]*)\]| ([^ ]*))/gm),
						].map((match) => match[1] ?? match[2]);
						if (
							(scenario.page && !page.includes(scenario.page)) ||
							(scenario.commit !== undefined && commit !== scenario.commit)
						) {
							throw new Error(
								`${schema}/${scenario.id} 编码验证失败：期望首页 ${scenario.page ?? "不限"}、上屏 ${scenario.commit ?? "不限"}；实际上屏 ${commit}\n${last}`,
							);
						}
					}
				}
				await driver.close();
				driver = undefined;
				rmSync(caseDir, { recursive: true, force: true });
			}
			console.log(`${SCHEMA_NAMES[schema]}：完成`);
		}
		const groups = new Map<string, Sample[]>();
		for (const sample of samples) {
			const feedback =
				sample.schema !== "snow_yipin" ||
				sample.kind === "chord-feedback" ||
				(sample.kind === "control" && sample.key !== "{space}");
			for (const group of [
				`${sample.schema}/${sample.phase}`,
				`${sample.schema}/${sample.phase}/${sample.case}`,
				`${sample.schema}/${sample.phase}/${sample.case}/event:${sample.index}:${sample.key}`,
				`${sample.schema}/${sample.phase}/kind:${sample.kind}`,
				...(feedback
					? [
							`${sample.schema}/${sample.phase}/feedback`,
							`${sample.schema}/${sample.phase}/${sample.case}/feedback`,
						]
					: []),
			]) {
				if (!groups.has(group)) groups.set(group, []);
				groups.get(group)!.push(sample);
			}
		}
		const summary = Object.fromEntries(
			[...groups].map(([key, group]) => [
				key,
				distribution(group.map((s) => s.ms)),
			]),
		);
		const metadata = {
			date: new Date().toISOString(),
			ref: ref || "working-tree",
			commit: revision,
			sourceSha256,
			dirty,
			rimeVersions,
			version: readFileSync(join(source, "lua/snow/snow.lua"), "utf8").match(
				/snow.version = "([^"]+)"/,
			)?.[1],
			binary,
			rounds,
			casePattern: casePattern.source,
			casesSha256: new Bun.CryptoHasher("sha256")
				.update(JSON.stringify(LATENCY_CASES))
				.digest("hex"),
			consoleSha256: new Bun.CryptoHasher("sha256")
				.update(readFileSync(binary))
				.digest("hex"),
			platform: platform(),
			release: release(),
			arch: arch(),
			cpu: cpus()[0]?.model,
			metric:
				"单事件写入 stdin 至完整候选页及只读屏障返回的墙钟毫秒；包含 IPC、控制台序列化，不含界面绘制",
		};
		const report = {
			metadata,
			controls: Object.fromEntries(
				Object.entries(controls).map(([schema, values]) => [
					schema,
					distribution(values),
				]),
			),
			summary,
			slowest: samples.toSorted((a, b) => b.ms - a.ms).slice(0, 30),
			cases: LATENCY_CASES,
		};
		const budgetFailures = ci ? latencyBudgetFailures(report) : [];
		writeFileSync(
			join(output, "report.json"),
			`${JSON.stringify({ ...report, budget: ci ? { limits: LATENCY_BUDGET, failures: budgetFailures } : undefined }, null, 2)}\n`,
		);
		for (const schema of schemas) {
			for (const phase of ["first", "repeat"]) {
				const stats = summary[`${schema}/${phase}/feedback`];
				if (stats)
					console.log(
						`${SCHEMA_NAMES[schema]} ${phase} n=${stats.n} p50=${stats.p50.toFixed(2)} p95=${stats.p95.toFixed(2)} p99=${stats.p99.toFixed(2)} max=${stats.max?.toFixed(2)} ms`,
					);
			}
		}
		console.log(`原始样本及报告：${output}`);
		if (budgetFailures.length)
			throw new Error(`统一性能预算不通过：\n${budgetFailures.join("\n")}`);
		if (ci)
			console.log(
				`✓ 五方案 p50 < ${LATENCY_BUDGET.p50}、p95 < ${LATENCY_BUDGET.p95}、p99 < ${LATENCY_BUDGET.p99} ms`,
			);
		// 按场景和事件类型检查，避免大量便宜事件掩盖少量昂贵事件。
		const failed = Object.entries(summary).filter(
			([key, stats]) => key.includes("/repeat/") && stats.p99 > maxP99,
		);
		if (failed.length)
			throw new Error(
				`p99 超过 ${maxP99} ms：${failed.map(([key]) => key).join(", ")}`,
			);
	} finally {
		await driver?.kill();
		rmSync(base, { recursive: true, force: true });
	}
}

if (import.meta.main) await main();
