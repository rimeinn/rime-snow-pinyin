import { expect, test } from "bun:test";
import { spawnSync } from "node:child_process";
import {
	chmodSync,
	mkdtempSync,
	readFileSync,
	rmSync,
	writeFileSync,
} from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { ROOT } from "./lib/paths";

test("初始化失败时等待控制台结束，保留错误及退出前的日志", () => {
	const dir = mkdtempSync(join(tmpdir(), "snow-failure-log-"));
	try {
		const binary = join(dir, "console");
		writeFileSync(
			binary,
			`#!/usr/bin/env bun
import { createInterface } from "node:readline";
console.error("初始化日志");
process.on("SIGTERM", () => {
  console.error("退出前的最后一条日志");
  process.exit(0);
});
for await (const line of createInterface({ input: process.stdin })) {
  if (line === "print schema list") {
    console.log("Lua audit error: 模拟初始化失败");
    console.log("current schema: [snow_sipin]");
  }
}
`,
		);
		chmodSync(binary, 0o755);
		const output = join(dir, "output");
		const result = spawnSync(
			process.execPath,
			[
				join(ROOT, "scripts/benchmark-latency.ts"),
				"sipin",
				"--case",
				"^single$",
				"--rounds",
				"2",
				"--console",
				binary,
				"--output-dir",
				output,
			],
			{ cwd: ROOT, encoding: "utf8", timeout: 20_000 },
		);
		expect(result.error).toBeUndefined();
		expect(result.status).toBe(1);
		const log = readFileSync(join(output, "snow_sipin.log"), "utf8");
		expect(log).toContain("初始化日志");
		expect(log).toContain("模拟初始化失败");
		expect(log).toContain("退出前的最后一条日志");
	} finally {
		rmSync(dir, { recursive: true, force: true });
	}
}, 30_000);
