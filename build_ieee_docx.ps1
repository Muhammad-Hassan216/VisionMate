$ErrorActionPreference = 'Stop'

$workspace = 'd:\develop\flutter_application_1\flutter_application_1'
$mdPath = Join-Path $workspace 'visionmate_ieee_paper_draft.md'
$tempDocx = Join-Path $workspace 'visionmate_ieee_paper_draft_from_md.docx'
$finalDocx = Join-Path $workspace 'visionmate_ieee_paper_final_camera_ready_v3.docx'
$downloadsDocx = 'C:\Users\Hassan\Downloads\visionmate_ieee_paper_final_camera_ready_v3.docx'

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

$word = New-Object -ComObject Word.Application
$word.Visible = $false

# Step 1: Markdown -> DOCX
$doc = $word.Documents.Open((Resolve-Path $mdPath).Path)
$doc.SaveAs2($tempDocx, 16)
$doc.Close()

# Step 2: Apply IEEE-like formatting
$doc = $word.Documents.Open($tempDocx)

$doc.PageSetup.PaperSize = 7 # A4
$doc.PageSetup.TopMargin = $word.CentimetersToPoints(1.9)
$doc.PageSetup.BottomMargin = $word.CentimetersToPoints(1.9)
$doc.PageSetup.LeftMargin = $word.CentimetersToPoints(1.43)
$doc.PageSetup.RightMargin = $word.CentimetersToPoints(1.43)

$doc.Content.Font.Name = 'Times New Roman'
$doc.Content.Font.Size = 10
$doc.Content.ParagraphFormat.Alignment = 3
$doc.Content.ParagraphFormat.SpaceAfter = 0
$doc.Content.ParagraphFormat.LineSpacingRule = 0

$introStart = $null
$inRefs = $false

for ($i = 1; $i -le $doc.Paragraphs.Count; $i++) {
  $p = $doc.Paragraphs.Item($i)
  $t = $p.Range.Text.Trim("`r", "`n")

  if ($t -eq '') { continue }

  if ($t -eq '---') {
    $p.Range.Text = "`r"
    continue
  }

  if ($t.StartsWith('# ')) {
    $new = $t.Substring(2)
    $p.Range.Text = $new + "`r"
    $p.Range.Font.Name = 'Times New Roman'
    $p.Range.Font.Size = 24
    $p.Range.Font.Bold = 0
    $p.Range.ParagraphFormat.Alignment = 1
    continue
  }

  if ($t -match '^\*\*.*\*\*$') {
    $new = $t.Trim('*')
    $p.Range.Text = $new + "`r"
    $p.Range.Font.Size = 11
    $p.Range.Font.Bold = 0
    $p.Range.ParagraphFormat.Alignment = 1
    continue
  }

  if ($t.StartsWith('*Corresponding author:')) {
    $new = $t.TrimStart('*')
    $p.Range.Text = $new + "`r"
    $p.Range.Font.Size = 9
    $p.Range.Font.Bold = 0
    $p.Range.ParagraphFormat.Alignment = 1
    continue
  }

  if ($t.StartsWith('## ')) {
    $h = $t.Substring(3)
    if ($h -eq 'Abstract') {
      $p.Range.Text = 'Abstract-' + "`r"
      $p.Range.Font.Size = 9
      $p.Range.Font.Bold = 1
      $p.Range.ParagraphFormat.Alignment = 0
      continue
    }
    if ($h -eq 'Keywords') {
      $p.Range.Text = 'Keywords-' + "`r"
      $p.Range.Font.Size = 9
      $p.Range.Font.Bold = 1
      $p.Range.ParagraphFormat.Alignment = 0
      continue
    }
    if ($h -eq 'ACKNOWLEDGMENT' -or $h -eq 'REFERENCES') {
      $p.Range.Text = $h + "`r"
      $p.Range.Font.Size = 10
      $p.Range.Font.Bold = 0
      $p.Range.ParagraphFormat.Alignment = 1
      $inRefs = ($h -eq 'REFERENCES')
      continue
    }

    $p.Range.Text = $h + "`r"
    $p.Range.Font.Size = 10
    $p.Range.Font.Bold = 0
    $p.Range.ParagraphFormat.Alignment = 1
    if ($h -eq 'I. INTRODUCTION' -and $introStart -eq $null) { $introStart = $p.Range.Start }
    $inRefs = $false
    continue
  }

  if ($t.StartsWith('### ')) {
    $p.Range.Text = $t.Substring(4) + "`r"
    $p.Range.Font.Size = 10
    $p.Range.Font.Italic = 1
    $p.Range.Font.Bold = 0
    $p.Range.ParagraphFormat.Alignment = 0
    continue
  }

  if ($t.StartsWith('#### ')) {
    $p.Range.Text = $t.Substring(5) + "`r"
    $p.Range.Font.Size = 10
    $p.Range.Font.Italic = 1
    $p.Range.Font.Bold = 0
    $p.Range.ParagraphFormat.Alignment = 0
    continue
  }

  if ($t.StartsWith('- ')) {
    $p.Range.Text = $t.Substring(2) + "`r"
    $p.Range.ListFormat.ApplyBulletDefault() | Out-Null
    $inRefs = $false
    continue
  }

  if ($t -match '^\[[0-9]+\]') {
    $inRefs = $true
    $p.Range.Font.Size = 8
    $p.Range.ParagraphFormat.Alignment = 3
    $p.Range.ParagraphFormat.LeftIndent = $word.CentimetersToPoints(0.63)
    $p.Range.ParagraphFormat.FirstLineIndent = -$word.CentimetersToPoints(0.63)
    continue
  }

  if ($inRefs) {
    $p.Range.Font.Size = 8
    $p.Range.ParagraphFormat.Alignment = 3
  }
}

# Step 3: Two-column layout from introduction
if ($introStart -ne $null) {
  $r = $doc.Range($introStart, $introStart)
  $r.InsertBreak(3) # wdSectionBreakContinuous
  $sec = $doc.Range($r.Start, $doc.Content.End).Sections.Item(1)
  $sec.PageSetup.TextColumns.SetCount(2)
  $sec.PageSetup.TextColumns.Spacing = $word.CentimetersToPoints(0.42)
}

# Step 4: Convert markdown pipe tables to native Word tables
$i = 1
while ($i -le $doc.Paragraphs.Count) {
  $line = $doc.Paragraphs.Item($i).Range.Text.Trim("`r", "`n")

  if (IsPipeLine $line) {
    $start = $i
    $end = $i

    while ($end -lt $doc.Paragraphs.Count) {
      $next = $doc.Paragraphs.Item($end + 1).Range.Text.Trim("`r", "`n")
      if (IsPipeLine $next) { $end++ } else { break }
    }

    $rows = New-Object System.Collections.Generic.List[object]

    for ($k = $start; $k -le $end; $k++) {
      $raw = $doc.Paragraphs.Item($k).Range.Text.Trim("`r", "`n").Trim()
      if ($raw.Length -eq 0) { continue }
      if ($raw.StartsWith('|')) { $raw = $raw.Substring(1) }
      if ($raw.EndsWith('|')) { $raw = $raw.Substring(0, $raw.Length - 1) }
      $cells = $raw.Split('|') | ForEach-Object { $_.Trim() }
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
      $tbl = $tblRange.ConvertToTable(1, $cols)
      $tbl.Borders.Enable = 1
      $tbl.Range.Font.Name = 'Times New Roman'
      $tbl.Range.Font.Size = 8
      $tbl.Rows.Item(1).Range.Bold = 1
      $tbl.Rows.Alignment = 1
      $tbl.AllowAutoFit = $false
      $tbl.PreferredWidthType = 1
      $tbl.PreferredWidth = 100

      $i = 1
      continue
    }

    $i = $end + 1
    continue
  }

  $i++
}

# Step 5: Remove headers/footers
foreach ($s in $doc.Sections) {
  foreach ($h in $s.Headers) { $h.Range.Text = '' }
  foreach ($f in $s.Footers) { $f.Range.Text = '' }
}

$doc.SaveAs2($finalDocx, 16)
$doc.Close()
$word.Quit()

Copy-Item -Path $finalDocx -Destination $downloadsDocx -Force
Write-Output "FINAL_DOCX_CREATED: $finalDocx"
Write-Output "COPIED_TO_DOWNLOADS: $downloadsDocx"
