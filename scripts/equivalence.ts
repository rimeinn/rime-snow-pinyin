import { readFileSync, writeFileSync } from "fs";

const keys_str = "qwertyuiopasdfghjkl;zxcvbnm,./";
const keys = [...keys_str];
const c2 = keys.map((c) => keys.map((s) => c + s)).flat();
const c3 = keys.map((c) => c2.map((s) => c + s)).flat();
const c4 = keys.map((c) => c3.map((s) => c + s)).flat();
const equiv = new Map<string, number>(
	readFileSync("linear.txt", "utf-8")
		.trim()
		.split("\n")
		.map((line) => line.split("\t") as [string, string])
		.map(([a, b]) => [a, parseFloat(b)]),
);

const result: [string, number][] = [];
const p = 1 / 2;
const A = -0.5;

for (const s of c2) {
	result.push([s, equiv.get(s) ?? 0]);
}
for (const s of c3) {
	const e12 = equiv.get(s[0] + s[1]) ?? 0;
	const e23 = equiv.get(s[1] + s[2]) ?? 0;
	const e13 = equiv.get(s[0] + s[2]) ?? 0;
	const e13n = p * Math.max(0, e13 + A - e12 - e23);
	result.push([s, e13n]);
}
for (const s of c4) {
	const e12 = equiv.get(s[0] + s[1]) ?? 0;
	const e23 = equiv.get(s[1] + s[2]) ?? 0;
	const e34 = equiv.get(s[2] + s[3]) ?? 0;
	const e14 = equiv.get(s[0] + s[3]) ?? 0;
	const e14n = p * p * Math.max(0, e14 + A * 2 - e12 - e23 - e34);
	result.push([s, e14n]);
}
writeFileSync(
	"linear_multiple.txt",
	result.map(([s, e]) => `${s}\t${e.toFixed(2)}`).join("\n"),
	"utf-8",
);
