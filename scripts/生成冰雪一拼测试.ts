import { parse } from "csv-parse/sync";
import { readFileSync, writeFileSync } from "fs";
import { dump } from "js-yaml";

const 声介映射 = new Map(
	`
d	F
i	D
sh	S
ji	A
zh	G
xi	R
u	E
b	W
z	Q
f	T
gu	V
m	C
li	X
h	Z
l	B
qi	DF
v	SD
g	SF
t	AF
hu	ER
zhu	WE
r	WR
ch	QR
du	CV
di	XC
k	XV
#	ZV
n	DG
bi	SG
shu	AG
zu	EF
ti	WF
mi	QF
chu	DV
qv	SV
s	AV
ni	CF
c	XF
tu	ZF
xv	DR
jv	SR
su	AR
p	EG
lu	WG
ru	QG
ku	CG
pi	XG
cu	ZG
lv	AS
nu	SE
nv	XD
`
		.trim()
		.split("\n")
		.map((line) => line.split("\t") as [string, string]),
);

const 韵调映射 = new Map(
	`
4	J
e1	K
3	L
1	;
e4	H
2	U
eng1	I
an4	O
e2	P
eng2	Y
e3	M
en1	,
ei4	.
an2	/
a1	N
eng4	JK
ao4	KL
en2	JL
ai4	J;
an1	UI
a4	IO
ang4	UO
ou3	UP
an3	M,
ang1	,.
ou4	M.
ao3	M/
en4	HK
ai2	HL
eng3	H;
ang2	JI
ang3	JO
en3	JP
a3	MK
ou2	ML
ei2	M;
ei3	J,
ao1	J.
ou1	J/
ei1	UK
a2	UL
ao2	U;
ai3	HI
ai1	HO
`
		.trim()
		.split("\n")
		.map((line) => line.split("\t") as [string, string]),
);

interface 拼合 {
	拼音: string;
	声介: string;
	韵调: string;
}

const csv: 拼合[] = parse(readFileSync("scripts/冰雪一拼拼合表.txt"), {
	delimiter: "\t",
	columns: ["拼音", "声介", "韵调"],
});

const 分组: 拼合[][] = [];

let last: string = "";
const group: 拼合[] = [];
for (const x of csv) {
	if (x.拼音.replace(/\d/, "") === last.replace(/\d/, "")) {
		group.push(x);
	} else {
		if (group.length > 0) {
			分组.push([...group]);
			group.length = 0;
		}
		last = x.拼音;
		group.push(x);
	}
}

interface Test {
	send: string;
	assert: string;
}

const 被合并的音节: Map<string, string> = new Map([
	["hm", "hen"],
	["hng", "heng"],
	["ng", "eng"],
	["n", "en"],
	["m", "mu"],
	["o", "e"],
	["yo", "ye"],
	["lo", "le"],
	["me", "mo"],
]);

const tests: Test[] = [];

for (const 组 of 分组) {
	const 随机选择 = 组[Math.floor(Math.random() * 组.length)];
	const { 拼音, 声介, 韵调 } = 随机选择;
	const 声介键位 = 声介映射.get(声介);
	const 韵调键位 = 韵调映射.get(韵调);
	if (!声介键位 || !韵调键位) {
		console.error(`${拼音} 声介 ${声介} 韵调 ${韵调} 键位映射未找到`);
		continue;
	}
	const lookup: Record<string, string> = {
		",": "comma",
		".": "period",
		";": "semicolon",
		"/": "slash",
	};
	const 所有按键 = Array.from((声介键位 + 韵调键位).toLowerCase());
	const 所有按键松开 = 所有按键.map((x) => `{Release+${lookup[x] ?? x}}`);
	const send = 所有按键.concat(所有按键松开).join("");
	const 不带调拼音 = 拼音.slice(0, 拼音.length - 1);
	const 最终拼音 = 被合并的音节.has(不带调拼音)
		? 拼音.replace(不带调拼音, 被合并的音节.get(不带调拼音)!)
		: 拼音;
	const assert = `preedit == "${最终拼音}"`;
	tests.push({ send, assert });
}

const content = dump({ deploy: { syllable: { tests } } });

writeFileSync("spec/snow_yipin.test.yaml.snippet", content);
