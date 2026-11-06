// 将性能报告转为 GitHub Actions 运行摘要，预算超限时仍展示完整结果。
import { readFileSync } from "node:fs";
import { SCHEMA_NAMES } from "./data/latency-cases";
import {
	LATENCY_BUDGET,
	latencyBudgetFailures,
	type LatencyReport,
} from "./lib/latency-budget";

interface SummaryReport extends LatencyReport {
	metadata: LatencyReport["metadata"] & {
		platform: string;
		arch: string;
		cpu?: string;
		commit: string;
	};
}

function cell(value: string): string {
	return value
		.replace(/&/g, "&amp;")
		.replace(/</g, "&lt;")
		.replace(/>/g, "&gt;")
		.replace(/\|/g, "&#124;")
		.replace(/[\r\n]/g, " ");
}

export function formatLatencySummary(report: SummaryReport): string {
	const { metadata, summary } = report;
	const failures = latencyBudgetFailures(report);
	const schemas = Object.keys(SCHEMA_NAMES);
	const globalFailures = failures.filter(
		(failure) => !schemas.some((schema) => failure.includes(schema)),
	);
	const ms = (value: number | undefined) =>
		typeof value === "number" && Number.isFinite(value)
			? value.toFixed(2)
			: "—";
	const lines = [
		"## 按键反馈延迟",
		"",
		failures.length ? "❌ 统一性能预算未通过" : "✅ 五方案统一性能预算通过",
		"",
		`每场景 ${metadata.rounds} 轮；单位为毫秒。P50 < ${LATENCY_BUDGET.p50}、P95 < ${LATENCY_BUDGET.p95}、P99 < ${LATENCY_BUDGET.p99}；各场景及按键位置的 P99 < ${LATENCY_BUDGET.p99}，首次最大反馈 < ${LATENCY_BUDGET.firstMax}。`,
		"",
		"| 方案 | 重复样本数 | P50 | P95 | P99 | 重复最大 | 首次最大 | 预算 |",
		"| --- | ---: | ---: | ---: | ---: | ---: | ---: | --- |",
	];
	for (const schema of schemas) {
		const repeat = summary[`${schema}/repeat/feedback`];
		const first = summary[`${schema}/first/feedback`];
		const failed =
			globalFailures.length > 0 ||
			failures.some((failure) => failure.includes(schema));
		lines.push(
			`| ${SCHEMA_NAMES[schema]} | ${repeat?.n.toLocaleString("en-US") ?? "—"} | ${ms(repeat?.p50)} | ${ms(repeat?.p95)} | ${ms(repeat?.p99)} | ${ms(repeat?.max)} | ${ms(first?.max)} | ${failed ? "❌ 未通过" : "✅ 通过"} |`,
		);
	}
	if (failures.length) {
		lines.push("", "### 未通过的检查", "");
		for (const failure of failures.slice(0, 20))
			lines.push(`- ${cell(failure)}`);
		if (failures.length > 20)
			lines.push(`- 另有 ${failures.length - 20} 项，详见报告与测试日志。`);
	}
	lines.push(
		"",
		`环境：${cell(`${metadata.platform}/${metadata.arch}${metadata.cpu ? ` · ${metadata.cpu}` : ""}`)}；提交：${cell(metadata.commit.slice(0, 12))}。`,
		"",
		"原始样本、完整报告和控制台日志见本次运行的 latency 构件。",
		"",
	);
	return lines.join("\n");
}

if (import.meta.main) {
	const path = process.argv[2];
	if (!path || process.argv.length !== 3)
		throw new Error("用法：bun scripts/summarize-latency.ts <report.json>");
	process.stdout.write(
		formatLatencySummary(JSON.parse(readFileSync(path, "utf8"))),
	);
}
