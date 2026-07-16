$inputFolder  = "C:\WordFiles"
$outputFolder = "C:\WordFiles\Output"

New-Item -ItemType Directory -Force -Path $outputFolder | Out-Null

$files = Get-ChildItem $inputFolder -File |
    Where-Object {
        $_.Extension -match '^\.(doc|docx)$' -and
        $_.Name -notlike '~$*'
    } |
    Sort-Object CreationTime

$word = New-Object -ComObject Word.Application
$word.Visible = $false
$word.DisplayAlerts = 0

try {
    $merged = $word.Documents.Add()
    $firstDocument = $true

    foreach ($file in $files) {
        Write-Host "Processing: $($file.Name)"

        $doc = $word.Documents.Open($file.FullName, $false, $true)

        try {
            # 2 = wdStatisticPages
            $pageCount = $doc.ComputeStatistics(2)

            # 删除最后一页
            # 1 = wdGoToPage, 1 = wdGoToAbsolute
            $lastPage = $doc.GoTo(1, 1, $pageCount)
            $deleteRange = $doc.Range($lastPage.Start, $doc.Content.End)
            $deleteRange.Delete()

            $target = $merged.Range($merged.Content.End - 1)

            if (-not $firstDocument) {
                # 7 = wdPageBreak
                $target.InsertBreak(7)
                $target = $merged.Range($merged.Content.End - 1)
            }

            $target.FormattedText = $doc.Content.FormattedText
            $firstDocument = $false
        }
        finally {
            $doc.Close($false)
        }
    }

    $wordOutput = Join-Path $outputFolder "Merged.docx"
    $pdfOutput  = Join-Path $outputFolder "Merged.pdf"

    # 16 = DOCX
    $merged.SaveAs2($wordOutput, 16)

    # 17 = PDF
    $merged.ExportAsFixedFormat($pdfOutput, 17)

    Write-Host "Created:"
    Write-Host $wordOutput
    Write-Host $pdfOutput
}
finally {
    if ($merged) {
        $merged.Close($false)
    }

    $word.Quit()
}
