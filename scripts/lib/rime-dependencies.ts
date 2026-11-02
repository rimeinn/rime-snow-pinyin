import { copyFileSync, existsSync, mkdirSync } from "node:fs";
import { join } from "node:path";

// 发布包和 Rime 用户目录只需要子模块中的全拼方案、词典。
export const RIME_DEPENDENCIES = [
	"radical_pinyin.schema.yaml",
	"radical_pinyin.dict.yaml",
];
export const RADICAL_SUBMODULE = "deps/rime-radical-pinyin";

export function copyRimeDependencies(source: string, dest: string) {
	mkdirSync(dest, { recursive: true });
	for (const name of RIME_DEPENDENCIES) {
		// 已准备好的独立环境使用根目录文件；源码仓库从子模块取文件。
		const nested = join(source, RADICAL_SUBMODULE, name);
		const src = existsSync(nested) ? nested : join(source, name);
		if (!existsSync(src))
			throw new Error(
				`找不到 ${src}，请先运行 git submodule update --init ${RADICAL_SUBMODULE}`,
			);
		copyFileSync(src, join(dest, name));
	}
}
