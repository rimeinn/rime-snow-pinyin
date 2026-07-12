import { readFileSync, writeFileSync } from "fs";
import { resolve } from "path";

type Entry = {
	word: string;
	code: string;
	weight: number;
};

const sourcePath = resolve(process.cwd(), "rime-easy-en/easy_en.dict.yaml");
const targetPath = resolve(process.cwd(), "snow_yingpin.dict.yaml");
const latinWord = /^[a-z]+$/;

function parseEntries(content: string) {
	const lines = content.split(/\r?\n/);
	const dataStart = lines.findIndex((line) => line.trim() === "...");
	if (dataStart === -1) {
		throw new Error("未找到词典数据起始标记 ...");
	}

	const deduped = new Map<string, Entry>();
	for (const rawLine of lines.slice(dataStart + 1)) {
		const line = rawLine.trim();
		if (!line || line.startsWith("#")) continue;

		const parts = line.split("\t");
		if (parts.length < 2) continue;

		const word = parts[0]!.toLowerCase();
		const code = parts[1]!.toLowerCase();
		if (!latinWord.test(word)) continue;

		const weightText = parts[2];
		const parsedWeight = Number.parseInt(weightText ?? "0", 10);
		const weight = Number.isNaN(parsedWeight) ? 0 : parsedWeight;
		const key = `${word}\t${code}`;
		const existing = deduped.get(key);
		if (!existing || weight > existing.weight) {
			deduped.set(key, { word, code, weight });
		}
	}

	const result = [...deduped.values()].sort((a, b) => {
		if (b.weight !== a.weight) return b.weight - a.weight;
		if (a.word !== b.word) return a.word.localeCompare(b.word);
		return a.code.localeCompare(b.code);
	});

	return result.map(({ word, code, weight }) => ({
		word,
		code: code.replace(/(?<!^)[aeiou]/g, "").slice(0, 4),
		weight,
	}));
}

function renderDictionary(entries: Entry[]) {
	const header = [
		"# Rime dictionary",
		"# encoding: utf-8",
		"#",
		"# Generated from rime-easy-en/easy_en.dict.yaml",
		"#",
		"",
		"---",
		"name: snow_yingpin",
		'version: "0.1"',
		"sort: by_weight",
		"use_preset_vocabulary: false",
		"...",
		"",
		"",
	].join("\n");

	const body = entries
		.map(({ word, code, weight }) => `${word}\t${code}\t${weight}`)
		.join("\n");

	return `${header}${body}\n`;
}

const content = readFileSync(sourcePath, "utf8");
const entries = parseEntries(content);
writeFileSync(targetPath, renderDictionary(entries), "utf8");

console.log(`已导出 ${entries.length} 条词条到 ${targetPath}`);
