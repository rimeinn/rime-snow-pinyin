// 生成宇浩测评用码表

import { readFileSync, writeFileSync } from "fs";
import { SpellingAlgebra, 获取大字集拼音 } from "./utils";

const 通用规范拼音 = readFileSync("scripts/tygf.txt", "utf-8")
	.trim()
	.split("\n");

const 大字集拼音 = 获取大字集拼音();
const 已知汉字 = new Set<string>();
const 编码列表: { 汉字: string; 编码: string }[] = [
	{ 汉字: "的", 编码: ";" },
	{ 汉字: "了", 编码: "/" },
];
const 拼写运算 = new SpellingAlgebra("snow_sipin.schema.yaml", "sipin_algebra");

for (const 行 of readFileSync("snow_sipin.fixed.txt", "utf-8")
	.trim()
	.split("\n")) {
	if (行.startsWith("#")) continue;
	const [编码, 候选] = 行.split("\t");
	const 汉字 = 候选.split(" ")[0];
	if (/^[\u4E00-\u9FFF]$/.test(汉字) && 编码.length <= 3) {
		编码列表.push({ 汉字, 编码 });
	}
}

for (const 行 of 通用规范拼音) {
	const [汉字, 拼音] = 行.split("\t");
	if (已知汉字.has(汉字)) continue;
	已知汉字.add(汉字);
	编码列表.push({ 汉字, 编码: 拼写运算.apply(拼音) });
}

for (const { 汉字, 拼音 } of 大字集拼音) {
	if (已知汉字.has(汉字)) continue;
	已知汉字.add(汉字);
	编码列表.push({ 汉字, 编码: 拼写运算.apply(拼音) });
}

writeFileSync(
	"冰雪四拼一字一码.txt",
	编码列表.map((x) => `${x.汉字}\t${x.编码}`).join("\n"),
);
