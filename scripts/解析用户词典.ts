import { parse } from "csv-parse/sync";
import { readFileSync, writeFileSync } from "fs";
import { sortBy } from "lodash-es";
import { argv } from "process";

const filePath = argv[2];
interface 用户词 {
	词: string;
	拼音: string;
	词频: number;
}

// 读取文件内容
const input = readFileSync(filePath, "utf8");

// 预处理：移除注释行（以 # 开头）
const lines = input
	.split("\n")
	.filter((line) => line.trim() && !line.startsWith("#"));

// 使用 csv-parse 解析 tab 分隔内容
const records = parse(lines.join("\n"), {
	delimiter: "\t",
	relax_column_count: true,
	trim: true,
}) as string[][];

// 解析成所需结构
const 词表: 用户词[] = records.map(([拼音字段, 词, 注释字段]) => {
	const 拼音 = 拼音字段.trim();
	const 词频匹配 = 注释字段?.match(/c=(\d+)/);
	const 词频 = 词频匹配 ? parseInt(词频匹配[1], 10) : 0;
	return { 词, 拼音, 词频 };
});

const 排序词表 = sortBy(词表, (x) => -x.词频);

// 输出调试信息
writeFileSync(
	"output.txt",
	排序词表.map((x) => `${x.词}\t${x.拼音}\t${x.词频}\n`).join(""),
);
