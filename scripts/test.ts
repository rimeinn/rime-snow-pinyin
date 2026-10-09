// 并行运行五个方案的 mira 测试
//
//   bun scripts/test.ts                  # 全部方案
//   bun scripts/test.ts yipin qingyun    # 只跑指定方案，snow_ 前缀可省
//
// 每个方案用独立的 TMPDIR（mira 的工作目录固定为 $TMPDIR/mira，启动时会整个删掉）
// 和独立的缓存副本（带 patch 的部署会把改过的方案编译进缓存）
import { spawnSync } from "node:child_process";
import {
	constants,
	copyFileSync,
	existsSync,
	mkdirSync,
	mkdtempSync,
	readdirSync,
	rmSync,
	statSync,
	utimesSync,
	writeFileSync,
} from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

// 仓库根目录由本文件位置推出，因此不依赖运行时的工作目录
const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "..");

const SCHEMAS = [
	"snow_sipin",
	"snow_sanpin",
	"snow_yipin",
	"snow_jiandao",
	"snow_qingyun",
];

// 写时复制（APFS 上几乎不花时间），不支持时退化为普通复制
function clone(src: string, dest: string) {
	mkdirSync(dirname(dest), { recursive: true });
	copyFileSync(src, dest, constants.COPYFILE_FICLONE);
}

// 准备一份只含 Rime 需要的文件的源目录，相当于 CI 的全新 checkout：
// mira 每个部署都会把整个 source_dir 复制一遍，仓库里的 .git、node_modules、cache
// 会让每次部署多花约 1 秒；*.userdb、user.yaml 等本机文件也不该带进测试
function prepareSource(dest: string, schema: string) {
	const git = spawnSync(
		"git",
		["ls-files", "-z", "--cached", "--others", "--exclude-standard"],
		{ cwd: ROOT, encoding: "utf8" },
	);
	for (const file of git.stdout.split("\0")) {
		const src = join(ROOT, file);
		// 跳过子模块（目录）和已删除但仍在索引里的文件
		if (!file || !existsSync(src) || !statSync(src).isFile()) continue;
		clone(src, join(dest, file));
	}
	for (const file of readdirSync(join(ROOT, "rime-stroke"))) {
		if (file.startsWith("stroke")) {
			clone(join(ROOT, "rime-stroke", file), join(dest, file));
		}
	}
	// 每个部署默认会检查 schema_list 里的全部方案，只留被测方案能把部署从约 4 秒降到约 1.4 秒
	writeFileSync(
		join(dest, "default.custom.yaml"),
		`patch:\n  schema_list:\n    - schema: ${schema}\n`,
	);
}

// 复制目录里比目标新的文件并保留 mtime。用来给每个方案复制一份缓存，
// 以及把测试中重新编译过的产物写回仓库的 cache，下次就不用再编译
function syncNewer(from: string, to: string) {
	mkdirSync(to, { recursive: true });
	for (const file of readdirSync(from)) {
		const src = join(from, file);
		const dest = join(to, file);
		const { atime, mtime } = statSync(src);
		if (existsSync(dest) && mtime <= statSync(dest).mtime) continue;
		clone(src, dest);
		utimesSync(dest, atime, mtime);
	}
}

const names = process.argv.slice(2);
const schemas =
	names.length > 0
		? names.map((name) => (name.startsWith("snow_") ? name : `snow_${name}`))
		: SCHEMAS;
const unknown = schemas.filter((schema) => !SCHEMAS.includes(schema));
if (unknown.length > 0) throw new Error(`Unknown schema: ${unknown}`);

const base = mkdtempSync(join(tmpdir(), "snow-test-"));
const cache = join(ROOT, "cache");
const start = performance.now();
const results = await Promise.all(
	schemas.map(async (schema) => {
		const dir = join(base, schema);
		prepareSource(join(dir, "src"), schema);
		mkdirSync(join(dir, "tmp"));
		if (existsSync(cache)) syncNewer(cache, join(dir, "cache"));
		const proc = Bun.spawn(
			["mira", "-C", "cache", join("src", "spec", `${schema}.test.yaml`)],
			{
				cwd: dir,
				env: { ...process.env, TMPDIR: join(dir, "tmp") },
				stdout: "pipe",
				stderr: "pipe",
			},
		);
		const output =
			(await new Response(proc.stdout).text()) +
			(await new Response(proc.stderr).text());
		const code = await proc.exited;
		const seconds = ((performance.now() - start) / 1000).toFixed(1);
		console.log(`${code === 0 ? "✓" : "✗"} ${schema}  ${seconds}s`);
		writeFileSync(join(base, `${schema}.log`), output);
		if (existsSync(join(dir, "cache"))) syncNewer(join(dir, "cache"), cache);
		return { schema, code, output };
	}),
);

const failed = results.filter(({ code }) => code !== 0);
for (const { schema, output } of failed) {
	console.log(`\n========== ${schema} ==========`);
	// 只保留失败用例和末尾的汇总，省掉成百上千行 PASS
	const lines = output
		.split("\n")
		.filter((line) => !/^(SELECT|DEPLOY) |\.\.\. PASS$/.test(line));
	console.log(
		lines
			.join("\n")
			.replace(/\n{3,}/g, "\n\n")
			.trim(),
	);
}
if (failed.length > 0) {
	console.log(`\n完整输出见 ${base}/*.log`);
	process.exit(1);
}
rmSync(base, { recursive: true, force: true });
