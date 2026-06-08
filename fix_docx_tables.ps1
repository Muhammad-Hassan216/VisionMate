$ErrorActionPreference = 'Stop'

$path = 'd:\develop\flutter_application_1\flutter_application_1\visionmate_ieee_paper_final_camera_ready.docx'
$downloads = 'C:\Users\Hassan\Downloads\visionmate_ieee_paper_final_camera_ready.docx'

$word = New-Object -ComObject Word.Application
$word.Visible = $false
$doc = $word.Documents.Open($path)

function IsPipeLine([string]$txt) {
  return $txt.Trim().StartsWith('|')
}

function IsSeparatorRow($cells) {
  foreach ($c in $cells) {
    $v = $c.Trim()
    if ($v -eq '') { continue }
    if ($v -notmatch '^:?-{2,}:?$') { return $false }
  }
  return $true
}

$i = 1
$converted = 0

while ($i -le $doc.Paragraphs.Count) {
  $t = $doc.Paragraphs.Item($i).Range.Text.Trim("`r", "`n")

  if (IsPipeLine $t) {
    $start = $i
    $end = $i

    while ($end -lt $doc.Paragraphs.Count) {
      $nt = $doc.Paragraphs.Item($end + 1).Range.Text.Trim("`r", "`n")
      if (IsPipeLine $nt) { $end++ } else { break }
    }

    $rows = New-Object System.Collections.Generic.List[object]

    for ($k = $start; $k -le $end; $k++) {
      $line = $doc.Paragraphs.Item($k).Range.Text.Trim("`r", "`n").Trim()
      if ($line.Length -eq 0) { continue }
      if ($line.StartsWith('|')) { $line = $line.Substring(1) }
      if ($line.EndsWith('|')) { $line = $line.Substring(0, $line.Length - 1) }

      $cells = $line.Split('|') | ForEach-Object { $_.Trim() }
      if (IsSeparatorRow $cells) { continue }
      $rows.Add($cells)
    }

    if ($rows.Count -ge 2) {
      $cols = $rows[0].Count
      $tabLines = @()

      foreach ($r in $rows) {
        $arr = @($r)
        if ($arr.Count -lt $cols) {
          for ($x = $arr.Count; $x -lt $cols; $x++) { $arr += '' }
        }
        if ($arr.Count -gt $cols) { $arr = $arr[0..($cols - 1)] }
        $tabLines += ($arr -join "`t")
      }

      $newText = ($tabLines -join "`r") + "`r"

      $rStart = $doc.Paragraphs.Item($start).Range.Start
      $rEnd = $doc.Paragraphs.Item($end).Range.End
      $blk = $doc.Range($rStart, $rEnd)
      $blk.Text = $newText

      $tblRange = $doc.Range($rStart, $rStart + $newText.Length)
      $table = $tblRange.ConvertToTable(1, $cols)
      $table.Borders.Enable = 1
      $table.Range.Font.Name = 'Times New Roman'
      $table.Range.Font.Size = 8
      $table.Rows.Item(1).Range.Bold = 1
      $table.Rows.Alignment = 1
      $table.AllowAutoFit = $false
      $table.PreferredWidthType = 1
      $table.PreferredWidth = 100
      $converted++

      $i = 1
      continue
    }

    $i = $end + 1
    continue
  }

  $i++
}

$doc.Save()
$doc.Close()
$word.Quit()

if (Test-Path $downloads) {
  Copy-Item -Path $path -Destination $downloads -Force
}

Write-Output ("TABLES_CONVERTED=" + $converted)
