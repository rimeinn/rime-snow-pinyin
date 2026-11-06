import { expect, test } from "bun:test";
import { spawnSync } from "node:child_process";
import {
	copyFileSync,
	mkdirSync,
	mkdtempSync,
	rmSync,
	writeFileSync,
} from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { ROOT } from "./lib/paths";

test("发布检查拒绝不一致的标签和 YAML 版本", () => {
	const dir = mkdtempSync(join(tmpdir(), "snow-version-"));
	try {
		mkdirSync(join(dir, "scripts/lib"), { recursive: true });
		mkdirSync(join(dir, "lua/snow"), { recursive: true });
		for (const file of ["scripts/version.ts", "scripts/lib/paths.ts"])
			copyFileSync(join(ROOT, file), join(dir, file));
		writeFileSync(join(dir, "lua/snow/snow.lua"), 'snow.version = "0.3.14"\n');
		const yaml = join(dir, "snow_example.schema.yaml");
		writeFileSync(yaml, 'schema:\n  version: "0.3.14"\n');
		const check = (tag: string) =>
			spawnSync(
				process.execPath,
				[join(dir, "scripts/version.ts"), "--check", tag],
				{ encoding: "utf8" },
			);
		expect(check("v0.3.14").status).toBe(0);
		expect(check("v0.3.13").status).toBe(1);
		writeFileSync(yaml, 'schema:\n  version: "0.3.13"\n');
		expect(check("v0.3.14").status).toBe(1);
	} finally {
		rmSync(dir, { recursive: true, force: true });
	}
});
