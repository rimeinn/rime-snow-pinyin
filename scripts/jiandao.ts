import { readFileSync, writeFileSync } from "fs";

const codes = new Map<string, string[]>();
const raw = readFileSync("单字全码.txt", "utf8").trim().split("\n");

for (const line of raw) {
	const [word, code] = line.split("\t");
	codes.set(code, (codes.get(code) ?? []).concat(word));
}

writeFileSync(
	"snow_jiandao.fixed.txt",
	Array.from(codes.entries())
		.map(([code, words]) => `${code}\t${words.join(" ")}`)
		.join("\n"),
);

const jiandao = readFileSync("snow_jiandao.fixed.txt", "utf-8")
	.trim()
	.split("\n");
const tygf = new Set(
	readFileSync("snow/tygf.txt", "utf-8")
		.trim()
		.split("\n")
		.map((line) => line.split("\t")[0]),
);

const output: [string, string[]][] = [];

for (const line of jiandao) {
	if (line.startsWith("#")) continue;
	const [code, words] = line.split("\t");
	if (!code || !words) continue;
	const filtered = words.split(" ").filter((word) => tygf.has(word));
	if (filtered.length) output.push([code, filtered]);
}

writeFileSync(
	"snow_jiandao_filtered.txt",
	output.map(([code, words]) => `${code}\t${words.join(" ")}`).join("\n"),
);
