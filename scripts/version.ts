import { readFileSync, writeFileSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { Glob } from "bun";

// 版本号只写在 lua/snow/snow.lua 里，方案、词典的 version 和生成脚本都从这里取
const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "..");
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
	if (version) {
		const files = setVersion(version);
		console.log(
			`已把 lua/snow/snow.lua 和 ${files} 个 yaml 的版本改为 ${version}`,
		);
	} else {
		console.log(VERSION);
	}
}
