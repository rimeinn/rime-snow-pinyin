// 从雾凇词库生成带声调的冰雪多字词典，未能确定的读音另存到 diff/。
import { mkdirSync, writeFileSync } from "node:fs";
import { join, resolve as resolvePath } from "node:path";
import { parseArgs } from "node:util";
import matter from "gray-matter";
import { readDictionary } from "./lib/dictionary";
import { ROOT, rootPath } from "./lib/paths";
import { getPinyin, initializePinyin } from "./lib/word-pinyin";
import { VERSION } from "./version";

function getIceFrequency() {
	const frequency = new Map<string, [string, number][]>();
	for (const [word, pinyin, freq] of readDictionary(
		rootPath("deps/rime-ice/cn_dicts/8105.dict.yaml"),
	)) {
		frequency.set(
			word,
			(frequency.get(word) ?? []).concat([[pinyin, parseInt(freq, 10)]]),
		);
	}
	// sort the list in each entry
	for (const [_, list] of frequency) {
		list.sort((a, b) => b[1] - a[1]);
	}
	return frequency;
}

function resolve(
	word: string,
	simp_list: string[],
	ref_list: string[],
	dict: Map<string, string[]>,
) {
	let resolved = true;
	const chars = [...word];
	const updatedList = ref_list.map((syllable, i) => {
		const char = chars[i];
		const simp = simp_list[i];
		const possible = dict.get(char);
		if (!possible) {
			resolved = false;
			return syllable;
		}
		if (syllable.startsWith(simp)) return syllable;
		if (possible.length === 1) return possible[0];
		const matching = possible.filter((p) => p.startsWith(simp));
		if (matching.length === 1) return matching[0];
		resolved = false;
		return syllable;
	});
	return [resolved, updatedList.join(" ")] as const;
}

function readIceDictionary(
	name: string,
	iceFrequency: Map<string, [string, number][]>,
) {
	const data: [string, string, string][] = [];

	for (const row of readDictionary(
		rootPath(`deps/rime-ice/cn_dicts/${name}.dict.yaml`),
	)) {
		let [word, simp_pinyin, frequency] = row;
		if (frequency === undefined) {
			// 特殊处理 tencent
			frequency = simp_pinyin;
			const normal_word = word.replace(/[·（）：–]/g, "");
			const simp_list = [...normal_word].map((c) => {
				const possible_list = iceFrequency.get(c);
				if (possible_list === undefined) {
					console.log(`Missing ${c}`);
					return "";
				}
				return possible_list[0][0];
			});
			simp_pinyin = simp_list.join(" ");
		}
		data.push([word, simp_pinyin, frequency]);
	}
	return data;
}

function generate(
	name: string,
	dict: Map<string, string[]>,
	iceFrequency: Map<string, [string, number][]>,
	output: string,
	diagnostics: string,
) {
	const input = readIceDictionary(name, iceFrequency);
	const known_words = new Set();
	const undetermined: string[][] = [];
	const determined: string[][] = [];

	for (const [word, simp_pinyin, frequency] of input) {
		const normal_word = word.replace(/[·（）：–]/g, "");
		if (![...normal_word].every((c) => dict.has(c))) continue;
		const simp_list = simp_pinyin.split(" ");
		const ref_list = getPinyin(normal_word);
		const [valid, updated] = resolve(normal_word, simp_list, ref_list, dict);
		if (valid) {
			const hash = word + updated;
			if (known_words.has(hash)) continue;
			determined.push([word, updated, frequency]);
			known_words.add(hash);
		} else {
			undetermined.push([word, ref_list.join(" "), simp_pinyin, frequency]);
		}
	}

	const body = [""].concat(determined.map((row) => row.join("\t"))).join("\n");
	const header = {
		name: `snow_pinyin.${name}`,
		version: VERSION,
		sort: "by_weight",
		use_preset_vocabulary: false,
	};
	const content = matter.stringify(body, header, {
		delimiters: ["---", "..."],
	});

	writeFileSync(join(output, `snow_pinyin.${name}.dict.yaml`), content);

	writeFileSync(
		join(diagnostics, `${name}.txt`),
		undetermined.map((row) => row.join("\t")).join("\n"),
	);
}

function main() {
	const { values, positionals } = parseArgs({
		options: { "output-dir": { type: "string" } },
		allowPositionals: true,
	});
	const names = positionals.length ? positionals : ["base", "ext", "tencent"];
	if (names.some((name) => !["base", "ext", "tencent"].includes(name))) {
		throw new Error(
			"用法：bun scripts/generate-word-dicts.ts [base ext tencent] [--output-dir 目录]",
		);
	}
	const output = resolvePath(values["output-dir"] ?? ROOT);
	const diagnostics = values["output-dir"]
		? join(output, "diff")
		: rootPath("diff");
	mkdirSync(output, { recursive: true });
	mkdirSync(diagnostics, { recursive: true });
	const { dict, undetermined } = initializePinyin();
	writeFileSync(
		join(diagnostics, "complete.txt"),
		undetermined.map((row) => row.join("\t")).join("\n"),
	);
	const iceFrequency = getIceFrequency();
	for (const name of names) {
		generate(name, dict, iceFrequency, output, diagnostics);
		console.log(`已生成 snow_pinyin.${name}.dict.yaml`);
	}
}

if (import.meta.main) main();
