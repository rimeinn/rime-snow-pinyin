import { LATENCY_CASES, SCHEMA_NAMES } from "../data/latency-cases";

// 五个方案共用毫秒预算；首次遍历单独限制最大值，不用单次遍历估计每个事件的分位数。
export const LATENCY_BUDGET = {
	minimumRounds: 200,
	p50: 10,
	p95: 25,
	p99: 50,
	firstMax: 100,
};

interface Stats {
	n: number;
	p50: number;
	p95: number;
	p99: number;
	max?: number;
}

export interface LatencyReport {
	metadata: { rounds: number; ref: string; casesSha256: string };
	summary: Record<string, Stats>;
}

export function latencyBudgetFailures(report: LatencyReport): string[] {
	const failures: string[] = [];
	const { metadata, summary } = report;
	if (
		!Number.isInteger(metadata.rounds) ||
		metadata.rounds < LATENCY_BUDGET.minimumRounds
	)
		failures.push(
			`每场景至少 ${LATENCY_BUDGET.minimumRounds} 轮，实际 ${metadata.rounds}`,
		);
	if (metadata.ref !== "working-tree")
		failures.push("发布检查必须测当前工作区");
	const casesHash = new Bun.CryptoHasher("sha256")
		.update(JSON.stringify(LATENCY_CASES))
		.digest("hex");
	if (metadata.casesSha256 !== casesHash)
		failures.push("报告用例与当前用例不一致");
	function check(key: string, limits: Record<string, number>) {
		const stats = summary[key];
		if (!stats || !Number.isInteger(stats.n) || stats.n < 1) {
			failures.push(`缺少有效统计：${key}`);
			return;
		}
		for (const [metric, limit] of Object.entries(limits)) {
			const value = stats[metric as keyof Stats];
			if (
				typeof value !== "number" ||
				!Number.isFinite(value) ||
				value < 0 ||
				value >= limit
			)
				failures.push(`${key} ${metric}=${value} ms，须 < ${limit} ms`);
		}
	}
	for (const schema of Object.keys(SCHEMA_NAMES)) {
		check(`${schema}/repeat/feedback`, {
			p50: LATENCY_BUDGET.p50,
			p95: LATENCY_BUDGET.p95,
			p99: LATENCY_BUDGET.p99,
		});
		check(`${schema}/first/feedback`, { max: LATENCY_BUDGET.firstMax });
		for (const scenario of LATENCY_CASES[schema]) {
			check(`${schema}/repeat/${scenario.id}/feedback`, {
				p99: LATENCY_BUDGET.p99,
			});
			const prefix = `${schema}/repeat/${scenario.id}/event:`;
			const events = Object.keys(summary).filter((key) =>
				key.startsWith(prefix),
			);
			const count = scenario.keys.match(/\{[^{}]+\}|[^{}]/g)?.length ?? 0;
			if (events.length !== count)
				failures.push(`事件覆盖不完整：${schema}/${scenario.id}`);
			for (const key of events) {
				if (summary[key].n !== metadata.rounds - 1)
					failures.push(`重复事件样本不足：${key}`);
				// 包括并击按下、松开在内，任何固定位置都不能藏着经常发生的长尾。
				check(key, { p99: LATENCY_BUDGET.p99 });
			}
		}
	}
	return failures;
}
