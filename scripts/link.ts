import {
	cpSync,
	existsSync,
	lstatSync,
	mkdirSync,
	readdirSync,
	readFileSync,
	readlinkSync,
	rmSync,
	symlinkSync,
	unlinkSync,
} from "node:fs";
import { homedir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { Glob } from "bun";

// 仓库根目录由本文件位置推出，因此不依赖运行时的工作目录
const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "..");

// fcitx5 固定读取的 Rime 用户目录
const USER_DIR = join(homedir(), ".local", "share", "fcitx5", "rime");

// 使用 glob 模式匹配文件，支持星号通配符
// * 匹配任意字符（不跨路径分隔符），** 匹配任意字符（可跨路径分隔符）
const FILE_PATTERNS = [
	"snow_*.schema.yaml",
	"snow_*.dict.yaml",
	"snow_*.fixed.txt",
];

function isLink(path: string): boolean {
	try {
		return lstatSync(path).isSymbolicLink();
	} catch {
		return false;
	}
}

function pointsIntoRepo(path: string): boolean {
	return isLink(path) && readlinkSync(path).startsWith(`${ROOT}/`);
}

// 软链的来源与目标：仓库里的一份文件 ↔ Rime 用户目录里的同名文件
function pairs(): { src: string; dest: string }[] {
	const glob = new Glob(`{${FILE_PATTERNS.join(",")}}`);
	const list = [...glob.scanSync(ROOT)].sort().map((file) => ({
		src: join(ROOT, file),
		dest: join(USER_DIR, file),
	}));
	// lua/snow 整个目录软链，仓库里增删脚本时无需重新执行
	list.push({
		src: join(ROOT, "lua", "snow"),
		dest: join(USER_DIR, "lua", "snow"),
	});
	return list;
}

// 递归比较内容，用于判断用户目录里的那份是否可以安全丢弃
function same(src: string, dest: string): boolean {
	try {
		if (!lstatSync(dest).isDirectory()) {
			return readFileSync(src).equals(readFileSync(dest));
		}
		if (!lstatSync(src).isDirectory()) return false;
		const names = new Set([...readdirSync(src), ...readdirSync(dest)]);
		for (const name of names) {
			if (name === ".DS_Store") continue;
			const a = join(src, name);
			const b = join(dest, name);
			if (!existsSync(a) || !existsSync(b) || !same(a, b)) return false;
		}
		return true;
	} catch {
		return false;
	}
}

function link(force: boolean) {
	const list = pairs();
	const conflicts = list.filter(
		({ src, dest }) => !isLink(dest) && existsSync(dest) && !same(src, dest),
	);
	if (conflicts.length > 0 && !force) {
		console.error("以下文件与仓库内容不一致，软链会丢弃用户目录里的版本：");
		for (const { dest } of conflicts) console.error(`  ${dest}`);
		console.error(
			"\n先把需要的改动拷回仓库，或确认仓库版本正确后用 `link --force`。",
		);
		process.exit(1);
	}
	for (const { src, dest } of list) {
		if (isLink(dest) || existsSync(dest)) {
			rmSync(dest, { recursive: true, force: true });
		}
		mkdirSync(dirname(dest), { recursive: true });
		symlinkSync(src, dest);
	}
	// 清理指向仓库、但源文件已经删除的残留软链
	for (const name of readdirSync(USER_DIR)) {
		const dest = join(USER_DIR, name);
		if (!pointsIntoRepo(dest) || existsSync(readlinkSync(dest))) continue;
		unlinkSync(dest);
		console.log(`清理 ${name}（仓库里已删除）`);
	}
	console.log(`已软链 ${list.length} 项到 ${USER_DIR}`);
}

function unlink() {
	let count = 0;
	for (const { src, dest } of pairs()) {
		if (!pointsIntoRepo(dest)) continue;
		unlinkSync(dest);
		cpSync(src, dest, { recursive: true });
		count++;
	}
	console.log(`已把 ${count} 项还原成独立副本`);
}

const args = process.argv.slice(2);
const command = args.find((arg) => !arg.startsWith("-"));

if (command === "link") {
	link(args.includes("--force"));
} else if (command === "unlink") {
	unlink();
} else {
	throw new Error(`Unknown command: ${command}`);
}
