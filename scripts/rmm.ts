import { readFileSync, writeFileSync } from "fs";

function 最大逆向匹配分词(词典: Map<string, number>, 文本: string) {
	const 词列表: string[] = [];
	const 字符列表 = [...文本];
	let 结束位置 = 字符列表.length;
	while (结束位置 > 0) {
		const 末字 = 字符列表[结束位置 - 1]!;
		if (!词典.has(末字)) {
			词列表.unshift(末字);
			结束位置 -= 1;
			continue;
		}
		for (let 开始位置 = 0; 开始位置 < 结束位置; 开始位置++) {
			const 词 = 字符列表.slice(开始位置, 结束位置).join("");
			if (词典.has(词)) {
				词列表.unshift(词);
				结束位置 = 开始位置;
				break;
			}
		}
	}
	return 词列表;
}

const base = process.argv[2];

const 基础多字词库 = new Set<string>(
	readFileSync("../DictLinglong/DictLinglong.txt", "utf-8").trim().split("\n"),
);
const 通用规范汉字 = new Set<string>(
	readFileSync("scripts/tygf.txt", "utf-8")
		.trim()
		.split("\n")
		.map((line) => line.split("\t")[0]!),
);
const 原始一字词频 = new Map<string, number>(
	readFileSync(base + "万象一字词频（推导）.txt", "utf-8")
		.trim()
		.split("\n")
		.map((line) => {
			const [word, frequency] = line.split("\t");
			return [word, +frequency];
		}),
);
const 词频 = new Map<string, number>();
通用规范汉字.forEach((word) => 词频.set(word, 原始一字词频.get(word) ?? 0));
基础多字词库.forEach((word) => 词频.set(word, 0));

const 多字词频 = (
	readFileSync(base + "万象多字词频.txt", "utf-8") +
	readFileSync(base + "万象多字词频 2.txt", "utf-8").trim()
)
	.split("\n")
	.map((line) => {
		const [word, frequency] = line.split("\t");
		return [word, +frequency] as const;
	});

for (const [word, frequency] of 多字词频) {
	const 分词结果 = 最大逆向匹配分词(词频, word);
	for (const 词 of 分词结果) {
		if (词频.has(词)) {
			词频.set(词, 词频.get(词)! + frequency);
		}
	}
}

词频.set("的", 词频.get("的")! / 3);

writeFileSync(
	"万象词频玲珑二次分词.txt",
	[...词频.entries()]
		.sort(([_, av], [__, bv]) => bv - av)
		.map(([key, value]) => {
			return `${key}\t${value}`;
		})
		.join("\n"),
	"utf-8",
);

let 一字词总频 = 0;
let 多字词总频 = 0;
for (const [word, frequency] of 词频) {
	const 词长 = [...word].length;
	if (词长 === 1) {
		一字词总频 += frequency;
	} else {
		多字词总频 += frequency * 词长;
	}
}
let 总频 = 一字词总频 + 多字词总频;
console.log(
	`一字词总频: ${一字词总频}, 占比: ${((一字词总频 / 总频) * 100).toFixed(2)}%`,
);

console.log(
	`多字词总频: ${多字词总频}, 占比: ${((多字词总频 / 总频) * 100).toFixed(2)}%`,
);
