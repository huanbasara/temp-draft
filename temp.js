const fs = require("fs");
const path = require("path");

const inputFolder = "D:\\Markdown";          // 修改成你的 Markdown 目录
const outputFile = "D:\\Markdown\\Merged.md"; // 输出文件

const files = fs.readdirSync(inputFolder)
    .filter(f => f.endsWith(".md") && f !== path.basename(outputFile))
    .sort((a, b) => {
        const ta = fs.statSync(path.join(inputFolder, a)).birthtimeMs;
        const tb = fs.statSync(path.join(inputFolder, b)).birthtimeMs;
        return ta - tb;
    });

let merged = "";

for (const file of files) {
    console.log(`Merging ${file}...`);
    merged += fs.readFileSync(path.join(inputFolder, file), "utf8");
    merged += "\n\n";
}

fs.writeFileSync(outputFile, merged, "utf8");

console.log("Done!");
