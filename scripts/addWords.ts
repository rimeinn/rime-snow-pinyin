import { readFileSync, writeFileSync } from "fs";

const dictionary = readFileSync("public/cache/dictionary.txt", "utf8")
	.split("\n")
	.map((line) => line.trim().split("\t"));
const dictionaryMap = new Map(dictionary as [string, string][]);

const pinyinMap = {
	一: "yi1",
	二: "er4",
	三: "san1",
	四: "si4",
	五: "wu3",
	六: "liu4",
	七: "qi1",
	八: "ba1",
	九: "jiu3",
	十: "shi2",
	百: "bai3",
	千: "qian1",
	万: "wan4",
	亿: "yi4",
	个: "ge4",
};

const digits = ["一", "二", "三", "四", "五", "六", "七", "八", "九"];
const teens = digits.map((n) => "十" + n);
const tys = digits.slice(1).map((n) => n + "十");
const under100 = tys.map((ty) => digits.map((n) => ty + n)).flat();
const powers = ["百", "千", "万", "亿"];
const digitsWithPowers = digits.map((n) => powers.map((p) => n + p)).flat();

const all = teens.concat(tys, under100, digitsWithPowers);

for (const word of all) {
	if (!dictionaryMap.has(word)) {
		const pinyin = Array.from(word)
			.map((c) => pinyinMap[c])
			.join(" ");
		dictionary.push([word, pinyin]);
	}
}

writeFileSync(
	"public/cache/dictionary-new.txt",
	dictionary.map((line) => line.join("\t")).join("\n"),
	"utf8",
);
