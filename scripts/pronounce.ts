// 使用符合冰雪拼音风格的注音方式来对词库注音
import { readFileSync, writeFileSync } from "fs";
import matter from "gray-matter";
import { getPinyin } from "./multiple";

function 读取词典(文件名: string) {
	const 内容 = readFileSync(文件名, "utf8").trim();
	const { content } = matter(内容, { delimiters: ["---", "..."] });
	const 词典 = new Map<string, string>();
	for (const 行 of content.split("\n")) {
		if (!行 || 行.startsWith("#")) continue;
		const [词, 拼音] = 行.split("\t");
		if (词 && 拼音) {
			词典.set(词, 拼音);
		}
	}
	return 词典;
}

const 词典列表 = ["base", "ext", "tencent"].map((类型) =>
	读取词典(`snow_pinyin.${类型}.dict.yaml`),
);
const 所有词典 = new Map([...词典列表[0], ...词典列表[1], ...词典列表[2]]);
const 待注音词组 = readFileSync(process.argv[2], "utf8")
	.trim()
	.split("\n")
	.map((行) => 行.split("\t")[0]);

const 输出结果: { 词: string; 拼音: string }[] = [];
for (const 词 of 待注音词组) {
	const 拼音 = 所有词典.get(词) ?? getPinyin(词).join(" ");
	输出结果.push({ 词, 拼音 });
}
writeFileSync(
	"output.txt",
	输出结果.map(({ 词, 拼音 }) => `${词}\t${拼音}`).join("\n") + "\n",
	"utf8",
);
