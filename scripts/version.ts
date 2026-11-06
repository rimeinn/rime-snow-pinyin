import { readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { Glob } from "bun";
import { ROOT } from "./lib/paths";

// 版本号只写在 lua/snow/snow.lua 里，方案、词典的 version 和生成脚本都从这里取
const LUA = join(ROOT, "lua", "snow", "snow.lua");
const LUA_PATTERN = /^snow\.version = "([^"]*)"$/m;
// 只改 YAML 头里的第一个 version：方案在 schema 下缩进两格，词典在顶层
const YAML_PATTERN = /^( *)version: .*$/m;

function read(): string {
	const match = readFileSync(LUA, "utf8").match(LUA_PATTERN);
	if (!match) throw new Error(`${LUA} 里没有 snow.version`);
	return match[1];
}

export const VERSION = read();

// 检查发布标签与全部 YAML 头，避免源码、安装包和标签版本不一致。
export function checkVersion(expected = VERSION): number {
	if (expected.replace(/^v/, "") !== VERSION)
		throw new Error(`发布版本 ${expected} 与 snow.version ${VERSION} 不一致`);
	let count = 0;
	const glob = new Glob("snow_*.{schema,dict}.yaml");
	for (const file of glob.scanSync(ROOT)) {
		const content = readFileSync(join(ROOT, file), "utf8");
		const actual = content.match(YAML_PATTERN)?.[0].trim();
		if (actual !== `version: "${VERSION}"`)
			throw new Error(`${file} 的版本与 snow.version ${VERSION} 不一致`);
		count++;
	}
	return count;
}

// 改写 snow.lua 和仓库根目录下所有方案、词典的版本号，返回改动的 yaml 个数
export function setVersion(version: string): number {
	writeFileSync(
		LUA,
		readFileSync(LUA, "utf8").replace(
			LUA_PATTERN,
			`snow.version = "${version}"`,
		),
	);
	let count = 0;
	const glob = new Glob("snow_*.{schema,dict}.yaml");
	for (const file of glob.scanSync(ROOT)) {
		const path = join(ROOT, file);
		const content = readFileSync(path, "utf8");
		if (!YAML_PATTERN.test(content)) continue;
		writeFileSync(
			path,
			content.replace(YAML_PATTERN, `$1version: "${version}"`),
		);
		count++;
	}
	return count;
}

// bun scripts/version.ts [版本号]：给出版本号时改写，否则打印当前版本
if (import.meta.main) {
	const version = process.argv[2];
	if (version === "--check") {
		const files = checkVersion(process.argv[3]);
		console.log(`✓ ${VERSION}：snow.version 与 ${files} 个 YAML 版本一致`);
	} else if (version) {
		const files = setVersion(version);
		console.log(
			`已把 lua/snow/snow.lua 和 ${files} 个 yaml 的版本改为 ${version}`,
		);
	} else {
		console.log(VERSION);
	}
}
