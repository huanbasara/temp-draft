const fs = require("fs");
const path = require("path");

const inputFolder = "./markdown";
const outputFile = "./merged.md";

const files = fs.readdirSync(inputFolder)
    .filter(f => f.endsWith(".md"))
    .sort();

let output = "";

for (const file of files) {
    console.log(`Merging ${file}`);

    output += `\n\n<!-- ${file} -->\n\n`;
    output += fs.readFileSync(path.join(inputFolder, file), "utf8");
}

fs.writeFileSync(outputFile, output);

console.log("Done!");
