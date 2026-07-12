import { readFileSync } from "fs";
import { load } from "js-yaml";
import { convert } from "pinyin-pro";

interface Replace {
	from: RegExp;
	to: string;
}

export class SpellingAlgebra {
	private rules: Replace[];

	constructor(schema: string, key: string) {
		const content = readFileSync(schema, "utf8");
		const yaml = load(content) as Record<string, any>;
		const rules: string[] = yaml[key];
		const parsed: Replace[] = [];
		rules.forEach((rule) => {
			const trimmed = rule.trim();
			const ruleParts = trimmed.split(trimmed.at(-1)!);
			if (ruleParts[0] === "xform" || ruleParts[0] === "derive") {
				parsed.push({
					from: new RegExp(ruleParts[1], "g"),
					to: ruleParts[2],
				});
			} else if (ruleParts[0] === "xlit") {
				const fromList = [...ruleParts[1]];
				const toList = [...ruleParts[2]];
				fromList.forEach((from, i) => {
					parsed.push({
						from: new RegExp(from, "g"),
						to: toList[i],
					});
				});
			}
		});
		parsed.push({ from: /^([a-z]{3})$/g, to: "$1o" });
		this.rules = parsed;
	}

	apply(code: string) {
		let final = code;
		for (const rule of this.rules) {
			final = final.replaceAll(rule.from, rule.to);
		}
		return final;
	}
}

export function 获取大字集拼音() {
	const 原始数据 = readFileSync("pinyin-data/pinyin.txt", "utf-8")
		.trim()
		.split("\n");
	const 处理结果: { 汉字: string; 拼音: string }[] = [];
	const 特殊处理: Record<string, string> = {
		m̄: "m1",
		hm: "hm5",
		ê̄: "ê1",
		ế: "ê2",
		ê̌: "ê3",
		ề: "ê4",
	};

	for (const line of 原始数据) {
		if (line.startsWith("#")) continue;
		const [code_str, pinyins] = line.split("#")[0]!.split(":");
		const 编码 = parseInt(code_str.trim().slice(2), 16);
		const 拼音列表 = pinyins.trim().split(",");
		const 汉字 = String.fromCodePoint(编码);
		for (const 原始拼音 of 拼音列表) {
			const 拼音 =
				特殊处理[原始拼音] ??
				convert(原始拼音, { format: "symbolToNum" })
					.replace("ü", "v")
					.replace("0", "5");
			处理结果.push({ 汉字, 拼音 });
		}
	}

	return 处理结果;
}
