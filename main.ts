// Entry point for the gta6-clipper-01 make.fun entry.
// The house reads the video itself through the YouTube Data API; all this
// program has to do is copy VIDEO.json from this repository into the
// output directory the grader points us at.
import { copyFileSync, existsSync, mkdirSync, readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const repoDir = process.env.MAKEFUN_BOT_DIR ?? dirname(fileURLToPath(import.meta.url));
const outDir = process.env.MAKEFUN_OUTPUT_DIR ?? "/output";
const source = join(repoDir, "VIDEO.json");

if (!existsSync(source)) {
  console.error(`VIDEO.json not found in ${repoDir}`);
  process.exit(1);
}

// Fail loudly here rather than at the grader if VIDEO.json is malformed or
// does not carry a YouTube video address.
const video = JSON.parse(readFileSync(source, "utf8")) as { url?: unknown };
if (typeof video.url !== "string" || !/youtube\.com|youtu\.be/.test(video.url)) {
  console.error(`VIDEO.json has no YouTube url: ${JSON.stringify(video)}`);
  process.exit(1);
}

mkdirSync(outDir, { recursive: true });
copyFileSync(source, join(outDir, "VIDEO.json"));
console.log(`copied VIDEO.json -> ${join(outDir, "VIDEO.json")}`);
