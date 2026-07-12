import { readFileSync, writeFileSync } from "fs";
import { 获取大字集拼音 } from "./utils";
import matter from "gray-matter";

const 通用规范拼音 = readFileSync("scripts/tygf.txt", "utf-8")
	.trim()
	.split("\n");
const 大字集拼音 = 获取大字集拼音();

const 已知拼音 = new Map<string, string[]>();

const 文件内容 = [
	"# 《通用规范汉字表》内读音依据《通用规范汉字字典》，收录了 8105 个汉字，共 8773 音",
	"# 其他汉字的读音依据 https://github.com/mozillazg/pinyin-data/blob/master/pinyin.txt",
];

文件内容.push(
	matter.stringify("", {
		name: "snow_pinyin",
		version: "0.1",
		sort: "by_weight",
		use_preset_vocabulary: false,
	}),
);
文件内容.push("# 字母");
文件内容.push(
	"# 用 ~ 和 ~~ 作为特殊音节的标记，具体如何输入可以由方案自行决定，不影响简拼",
);
for (const letter of "abcdefghijklmnopqrstuvwxyz") {
	文件内容.push(`${letter}\t~${letter}`);
}
文件内容.push("");
for (const letter of "abcdefghijklmnopqrstuvwxyz") {
	文件内容.push(`${letter.toUpperCase()}\t~~${letter}`);
}
文件内容.push("");
文件内容.push("# 数字");
for (const [index, number] of [
	"ling2",
	"yi1",
	"er4",
	"san1",
	"si4",
	"wu3",
	"liu4",
	"qi1",
	"ba1",
	"jiu3",
	"shi2",
].entries()) {
	文件内容.push(`${index}\t${number}`);
}
文件内容.push("");
文件内容.push("#《通用规范汉字字典》");
for (const line of 通用规范拼音) {
	let [char, pinyin, frequency] = line.split("\t");
	if (parseInt(frequency) < 2) {
		frequency = "2";
	}
	文件内容.push(`${char}\t${pinyin}\t${frequency}`);
	已知拼音.set(char, (已知拼音.get(char) || []).concat(pinyin));
}
文件内容.push("");
文件内容.push("# 大字集");
let 增补拼音总数 = 0;
for (const { 汉字, 拼音 } of 大字集拼音) {
	if (已知拼音.has(汉字)) {
		if (已知拼音.get(汉字)!.includes(拼音)) continue;
		增补拼音总数++;
		console.log(`增补拼音: ${汉字} ${拼音}`);
	}
	let 编码 = 汉字.codePointAt(0) ?? 0;
	let 权重 = 0x4e00 <= 编码 && 编码 <= 0x9fff ? 1 : 0;
	文件内容.push(`${汉字}\t${拼音}\t${权重}`);
}
writeFileSync("snow_pinyin.dict.yaml", 文件内容.join("\n"));

console.log(`增补拼音总数: ${增补拼音总数}`);
