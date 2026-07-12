import { readFileSync, writeFileSync } from "fs";

const 单字频率 = new Map<string, number>();
for (const line of readFileSync("万象单字频.txt", "utf-8").trim().split("\n")) {
	const [word, _, frequency] = line.split("\t");
	单字频率.set(word, (单字频率.get(word) ?? 0) + +frequency);
}
console.log(`单字频率数量: ${单字频率.size}`);
const multiples = readFileSync("万象多字词频.txt", "utf-8")
	.trim()
	.split("\n")
	.map((line) => {
		const [word, frequency] = line.split("\t");
		return { word, frequency: +frequency };
	});
for (const { word, frequency } of multiples) {
	for (const char of [...word]) {
		if (单字频率.has(char)) {
			const 扣除后频率 = 单字频率.get(char)! - frequency;
			if (扣除后频率 < 0)
				console.log(`Negative frequency for ${char}: ${扣除后频率}`);
			单字频率.set(char, 扣除后频率);
		}
	}
}

writeFileSync(
	"万象一字词频（推导）.txt",
	[...单字频率.entries()]
		.sort(([_, av], [__, bv]) => bv - av)
		.map(([key, value]) => {
			return `${key}\t${Math.max(0, value)}`;
		})
		.join("\n"),
	"utf-8",
);
