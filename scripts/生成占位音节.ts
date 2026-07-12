// # 针对所有可能的音节加上中括号
// - xform/^(u?[bpm])(a|ai|an|ang|ao|e|ei|en|eng|ou|i|ia|ian|iang|iao|ie|ien|ieng|iou)?([wyxq])$/[$1$2$3]/
// - xform/^(u?f)(a|an|ang|e|ei|en|eng|ou)?([wyxq])$/[$1$2$3]/
// - xform/^(u?[dt])(a|ai|an|ang|ao|e|ei|en|eng|ou|i|ia|ian|iao|ie|ieng|iou|u|uan|ue|uei|uen|ueng)?([wyxq])$/[$1$2$3]/
// - xform/^(u?[nl])(a|ai|an|ang|ao|e|ei|en|eng|ou|i|ia|ian|iang|iao|ie|ien|ieng|iou|u|uan|ue|uen|ueng|v|ve)([wyxq])$/[$1$2$3]/
// - xform/^(u?[gkhr]j?)(a|ai|an|ang|ao|e|ei|en|eng|ou|i|ia|ian|iang|iao|ie|ien|ieng|iou|u|ua|uai|uan|uang|ue|uei|uen|ueng|v|van|ve|ven|veng)?([wyxq])$/[$1$2$3]/
// - xform/^(u?[zcs]j)(a|ai|an|ang|ao|e|ei|en|eng|ou|u|ua|uai|uan|uang|ue|uei|uen|ueng)?([wyxq])$/[$1$2$3]/
// - xform/^(u?r)(an|ang|ao|e|en|eng|ou|u|ua|uan|ue|uei|uen|ueng)?([wyxq])$/[$1$2$3]/
// - xform/^(u?[zcs])(a|ai|an|ang|ao|e|ei|en|eng|ou|u|uan|ue|uei|uen|ueng)?([wyxq])$/[$1$2$3]/

import { readFileSync, writeFileSync } from "fs";

const 组合 = new Map([
	["b,p", "a,ai,an,ang,ao,o,ei,en,eng,ou,i,ian,iang,iao,ie,in,ing,u"],
	["m", "a,ai,an,ang,ao,o,e,ei,en,eng,ou,i,ian,iao,ie,in,ing,iu,u"],
	["f", "a,an,ang,o,ei,en,eng,ou,u"],
	[
		"d,t",
		"a,ai,an,ang,ao,e,ei,en,eng,ou,i,ia,ian,iao,ie,ing,iu,u,uan,uo,ui,un,ong",
	],
	[
		"n,l",
		"a,ai,an,ang,ao,o,e,ei,en,eng,ou,i,ia,ian,iang,iao,ie,in,ing,iu,u,uan,uo,un,ong,v,ve",
	],
	["g,k,h", "a,ai,an,ang,ao,e,ei,en,eng,ou,u,ua,uai,uan,uang,uo,ui,un,ong"],
	["j,q,x", "i,ia,ian,iang,iao,ie,in,ing,iu,u,uan,ue,un,iong"],
	[
		"zh,ch,sh",
		"i,a,ai,an,ang,ao,e,ei,en,eng,ou,u,ua,uai,uan,uang,uo,ui,un,ong",
	],
	["r", "i,an,ang,ao,e,en,eng,ou,u,ua,uan,uo,ui,un,ong"],
	["z,c,s", "i,a,ai,an,ang,ao,e,ei,en,eng,ou,u,uan,uo,ui,un,ong"],
	[
		"",
		"er,a,ai,an,ang,ao,o,e,ei,en,eng,ou,wu,wa,wai,wan,wang,wo,wei,wen,weng,yi,ya,yan,yang,yao,ye,yin,ying,you,yo,yu,yuan,yue,yun,yong,hm,hng,m,n,ng",
	],
]);

const 音节: string[] = [];

for (const [key, value] of 组合) {
	const keys = key.split(",");
	const values = value.split(",");
	for (const k of keys) {
		for (const v of values) {
			for (const d of ["1", "2", "3", "4"]) {
				const syllable = `${k}${v}${d}`;
				音节.push(syllable);
			}
		}
	}
}

const set = new Set(
	readFileSync("scripts/冰雪一拼拼合表.txt", "utf8")
		.trim()
		.split("\n")
		.map((x) => x.split("\t")[0]!),
);

for (const syllable of 音节) {
	if (!set.has(syllable)) {
		console.log("Extra syllable", syllable);
	}
}

for (const syllable of set) {
	if (!音节.includes(syllable)) {
		console.log("Missing syllable", syllable);
	}
}

writeFileSync("output.txt", 音节.map((x) => `🈚️\t${x}`).join("\n"));
