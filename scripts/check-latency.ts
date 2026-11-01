// 用统一发布预算检查保存的报告，不重新采样。
import { readFileSync } from "node:fs";
import { LATENCY_BUDGET, latencyBudgetFailures } from "./lib/latency-budget";

const path = process.argv[2];
if (!path || process.argv.length !== 3)
	throw new Error("用法：bun scripts/check-latency.ts <report.json>");
const failures = latencyBudgetFailures(JSON.parse(readFileSync(path, "utf8")));
if (failures.length)
	throw new Error(`性能预算不通过：\n${failures.join("\n")}`);
console.log(
	`✓ 五方案统一预算：p50 < ${LATENCY_BUDGET.p50}、p95 < ${LATENCY_BUDGET.p95}、p99 < ${LATENCY_BUDGET.p99} ms`,
);
