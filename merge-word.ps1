$inputFolder  = "C:\WordFiles"
$outputFolder = "C:\WordFiles\Output"
$tempFolder   = Join-Path $outputFolder "temp"

New-Item -ItemType Directory -Force -Path $outputFolder | Out-Null
Remove-Item $tempFolder -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $tempFolder | Out-Null

$files = Get-ChildItem $inputFolder -File |
    Where-Object {
        $_.Extension -match '^\.(doc|docx)$' -and
        $_.Name -notlike '~$*'
    } |
    Sort-Object CreationTime

if ($files.Count -eq 0) {
    throw "No Word files found."
}

$word = New-Object -ComObject Word.Application
$word.Visible = $false
$word.DisplayAlerts = 0

try {
    for ($i = 0; $i -lt $files.Count; $i++) {
        $file = $files[$i]
        $number = ($i + 1).ToString("0000")
        $pdfPath = Join-Path $tempFolder "$number.pdf"

        Write-Host "Converting: $($file.Name)"

        $doc = $word.Documents.Open($file.FullName, $false, $true)

        try {
            $doc.ExportAsFixedFormat($pdfPath, 17)
        }
        finally {
            $doc.Close($false)
        }
    }
}
finally {
    try { $word.Quit() } catch {}
}

$nodeScript = @'
const fs = require("fs");
const path = require("path");
const { PDFDocument } = require("pdf-lib");

async function main() {
    const inputFolder = process.argv[2];
    const outputFile = process.argv[3];

    const files = fs.readdirSync(inputFolder)
        .filter(name => name.toLowerCase().endsWith(".pdf"))
        .sort();

    const output = await PDFDocument.create();

    for (const file of files) {
        const filePath = path.join(inputFolder, file);
        const source = await PDFDocument.load(fs.readFileSync(filePath));
        const pageCount = source.getPageCount();

        if (pageCount <= 1) {
            console.log(`Skipped: ${file} only has one page`);
            continue;
        }

        console.log(`Merging: ${file}, keeping ${pageCount - 1} pages`);

        const pageIndexes = Array.from(
            { length: pageCount - 1 },
            (_, index) => index
        );

        const pages = await output.copyPages(source, pageIndexes);

        for (const page of pages) {
            output.addPage(page);
        }
    }

    if (output.getPageCount() === 0) {
        throw new Error("No pages were available to merge.");
    }

    fs.writeFileSync(outputFile, await output.save());
    console.log(`Created: ${outputFile}`);
}

main().catch(error => {
    console.error(error);
    process.exit(1);
});
'@

$nodeFile = Join-Path $tempFolder "merge.js"
$outputPdf = Join-Path $outputFolder "Merged.pdf"

Set-Content -Path $nodeFile -Value $nodeScript -Encoding UTF8

node $nodeFile $tempFolder $outputPdf

if ($LASTEXITCODE -ne 0) {
    throw "Node.js PDF merge failed."
}

Write-Host ""
Write-Host "Completed:"
Write-Host $outputPdf
