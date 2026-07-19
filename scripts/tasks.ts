import { copyFileSync, readdirSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import { Glob } from "bun";

// 使用 glob 模式匹配文件，支持星号通配符
// * 匹配任意字符（不跨路径分隔符），** 匹配任意字符（可跨路径分隔符）
const FILE_PATTERNS = [
	"snow_*.schema.yaml",
	"snow_*.dict.yaml",
	"snow_*.fixed.txt",
];

function resolveFiles(folder: string): string[] {
	const glob = new Glob(`{${FILE_PATTERNS.join(",")}}`);
	return [...glob.scanSync(folder)].sort();
}

function deploy(path: string) {
	for (const file of resolveFiles(".")) {
		copyFileSync(`./${file}`, `${path}/${file}`);
	}
	for (const file of readdirSync("./lua/snow/")) {
		copyFileSync(`./lua/snow/${file}`, `${path}/lua/snow/${file}`);
	}
}

function retrieve(path: string) {
	for (const file of resolveFiles(path)) {
		copyFileSync(`${path}/${file}`, `./${file}`);
	}
	for (const file of readdirSync(`${path}/lua/snow/`)) {
		copyFileSync(`${path}/lua/snow/${file}`, `./lua/snow/${file}`);
	}
}

let [command, type] = process.argv.slice(2);
type = type || "fcitx";
let path: string;
if (type === "squirrel") {
	path = join(homedir(), "Library", "Rime");
} else if (type === "fcitx") {
	path = join(homedir(), ".local", "share", "fcitx5", "rime");
} else {
	throw new Error(`Unknown type: ${type}`);
}

if (command === "deploy") {
	deploy(path);
} else if (command === "retrieve") {
	retrieve(path);
}
