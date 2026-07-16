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

$merged = $null

try {
    $merged = $word.Documents.Add()

    foreach ($file in $files) {
        Write-Host "Processing: $($file.Name)"

        $doc = $word.Documents.Open(
            $file.FullName,
            $false,  # ConfirmConversions
            $false   # ReadOnly
        )

        try {
            $doc.Repaginate()

            # 删除最后一页
            $pageCount = $doc.ComputeStatistics(2)

            if ($pageCount -gt 1) {
                $lastPage = $doc.GoTo(1, 1, $pageCount)
                $doc.Range($lastPage.Start, $doc.Content.End - 1).Delete()
            }
            else {
                # 如果整个文档只有一页，则删除这一页的内容
                $doc.Range(0, $doc.Content.End - 1).Delete()
            }

            # 保存临时 DOCX，再插入到总文档
            $tempFile = Join-Path $env:TEMP `
                ("merge_" + [Guid]::NewGuid().ToString() + ".docx")

            $doc.SaveAs2($tempFile, 16)
        }
        finally {
            $doc.Close($false)
        }

        $range = $merged.Range($merged.Content.End - 1)

        if ($merged.Content.End -gt 1) {
            $range.InsertBreak(7)
            $range = $merged.Range($merged.Content.End - 1)
        }

        $range.InsertFile($tempFile)
        Remove-Item $tempFile -Force
    }

    $docxPath = Join-Path $outputFolder "Merged.docx"
    $pdfPath  = Join-Path $outputFolder "Merged.pdf"

    $merged.SaveAs2($docxPath, 16)
    $merged.ExportAsFixedFormat($pdfPath, 17)

    Write-Host "Created:"
    Write-Host $docxPath
    Write-Host $pdfPath
}
finally {
    if ($null -ne $merged) {
        try { $merged.Close($false) } catch {}
    }

    if ($null -ne $word) {
        try { $word.Quit() } catch {}
    }
}
