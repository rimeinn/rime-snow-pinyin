import { readFileSync, renameSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { LATENCY_CASES, SCHEMA_NAMES } from "../data/latency-cases";
import type { LatencyReport } from "./latency-budget";
import { ROOT } from "./paths";

interface DocumentReport extends LatencyReport {
	metadata: LatencyReport["metadata"] & {
		date: string;
		platform: string;
		arch: string;
		cpu?: string;
		sourceSha256: string;
		rimeVersions: Record<string, string | undefined>;
	};
}

const START = "<!-- latency-results:start -->";
const END = "<!-- latency-results:end -->";

// 只更新本轮覆盖全部场景的方案；分方案测量保留其余行及各自的时间、环境和源码。
export function updateLatencyDocument(report: DocumentReport): string[] {
	if (report.metadata.ref !== "working-tree") return [];
	const { metadata, summary } = report;
	const schemas = Object.keys(SCHEMA_NAMES).filter((schema) =>
		LATENCY_CASES[schema].every((scenario) => {
			const prefix = `${schema}/repeat/${scenario.id}`;
			const events = Object.entries(summary).filter(([key]) =>
				key.startsWith(`${prefix}/event:`),
			);
			return (
				summary[`${prefix}/feedback`]?.n > 0 &&
				events.length === scenario.keys.match(/\{[^{}]+\}|[^{}]/g)?.length &&
				events.every(([, stats]) => stats.n === metadata.rounds - 1)
			);
		}),
	);
	if (!schemas.length) return [];
	const path = join(ROOT, "docs", "latency.md");
	const document = readFileSync(path, "utf8");
	const start = document.indexOf(START);
	const end = document.indexOf(END, start + START.length);
	if (start < 0 || end < 0) throw new Error("latency.md 缺少自动结果区块标记");
	const results = new Map<string, string[]>();
	const environments = new Map<string, string[]>();
	const names = new Set(Object.values(SCHEMA_NAMES));
	for (const line of document.slice(start, end).split("\n")) {
		if (!line.startsWith("|")) continue;
		const cells = line
			.split("|")
			.slice(1, -1)
			.map((cell) => cell.trim());
		if (!names.has(cells[0])) continue;
		if (cells.length === 7) results.set(cells[0], cells);
		if (cells.length === 5) environments.set(cells[0], cells);
	}
	const time = new Intl.DateTimeFormat("sv-SE", {
		timeZone: "Asia/Shanghai",
		dateStyle: "short",
		timeStyle: "medium",
	}).format(new Date(metadata.date));
	const cpu =
		metadata.cpu && metadata.cpu !== "unknown" ? ` · ${metadata.cpu}` : "";
	const environment = `${metadata.platform}/${metadata.arch}${cpu}`;
	const cell = (value: string) => value.replace(/[\r\n|]/g, " ");
	const updated: string[] = [];
	for (const schema of schemas) {
		const name = SCHEMA_NAMES[schema];
		const previous = environments.get(name)?.[1];
		if (
			previous &&
			Date.parse(`${previous.replace(" ", "T")}+08:00`) >
				Date.parse(metadata.date)
		)
			continue;
		const stats = summary[`${schema}/repeat/feedback`];
		const values = [stats.p50, stats.p95, stats.p99, stats.max ?? Number.NaN];
		if (
			values.some(
				(value) => typeof value !== "number" || !Number.isFinite(value),
			)
		)
			throw new Error(`${schema} 缺少完整延迟统计，未更新文档`);
		results.set(name, [
			name,
			String(metadata.rounds),
			stats.n.toLocaleString("en-US"),
			...values.map((value) => value.toFixed(2)),
		]);
		environments.set(name, [
			name,
			time,
			cell(environment),
			cell(metadata.rimeVersions[schema] ?? "未知"),
			`\`${metadata.sourceSha256.slice(0, 12)}\``,
		]);
		updated.push(schema);
	}
	if (!updated.length) return [];
	const rows = (table: Map<string, string[]>, columns: number) =>
		Object.values(SCHEMA_NAMES).map(
			(name) =>
				`| ${(table.get(name) ?? [name, ...Array(columns - 1).fill("未测")]).join(" | ")} |`,
		);
	const block = [
		START,
		"每行记录该方案最近一次完整场景采样，自动更新；数值取第 2 轮起的有效反馈，单位为毫秒。分方案测试保留其他方案各自的结果与测量环境。",
		"",
		"| 方案 | 轮数 | 样本数 | p50 | p95 | p99 | 最大值 |",
		"| --- | ---: | ---: | ---: | ---: | ---: | ---: |",
		...rows(results, 7),
		"",
		"| 方案 | 报告时间（北京时间） | 环境 | Rime | 源码快照 |",
		"| --- | --- | --- | --- | --- |",
		...rows(environments, 5),
		END,
	].join("\n");
	const temporary = `${path}.${process.pid}.tmp`;
	writeFileSync(
		temporary,
		document.slice(0, start) + block + document.slice(end + END.length),
	);
	renameSync(temporary, path);
	return updated;
}
