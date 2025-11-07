# GRIDLOCK Chapter Word Count Script
# Created: November 6, 2025
# Purpose: Count words in all chapter files and generate a comprehensive report

Write-Host "`n=== GRIDLOCK Chapter Word Count Analysis ===" -ForegroundColor Cyan
Write-Host "Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n" -ForegroundColor Gray

# Get all chapter files, excluding notes and other non-chapter files
$chapterFiles = Get-ChildItem -Path . -Filter "GRIDLOCK_Chapter*.md" | 
    Where-Object { 
        $_.Name -notmatch "Notes" -and 
        $_.Name -notmatch "Outline" -and
        $_.Name -notmatch "Review" -and
        $_.Name -notmatch "Revisions" -and
        $_.Name -notmatch "Bible"
    } |
    Sort-Object Name

if ($chapterFiles.Count -eq 0) {
    Write-Host "No chapter files found!" -ForegroundColor Red
    exit 1
}

Write-Host "Found $($chapterFiles.Count) chapter files`n" -ForegroundColor Green

# Function to count words in a file
function Get-WordCount {
    param([string]$FilePath)
    
    try {
        $content = Get-Content -Path $FilePath -Raw -ErrorAction Stop
        # Remove markdown headers and code blocks for more accurate count
        $content = $content -replace '#{1,6}\s+', ''  # Remove markdown headers
        $content = $content -replace '```[\s\S]*?```', ''  # Remove code blocks
        $content = $content -replace '`[^`]+`', ''  # Remove inline code
        $content = $content -replace '\*\*[^*]+\*\*', ''  # Remove bold
        $content = $content -replace '\*[^*]+\*', ''  # Remove italic
        
        # Split by whitespace and filter out empty strings
        $words = ($content -split '\s+' | Where-Object { $_.Trim() -ne '' })
        return $words.Count
    }
    catch {
        Write-Warning "Error reading $FilePath : $_"
        return 0
    }
}

# Process each chapter file
$results = @()
$totalWords = 0
$totalFiles = 0

foreach ($file in $chapterFiles) {
    $wordCount = Get-WordCount -FilePath $file.FullName
    $totalWords += $wordCount
    $totalFiles++
    
    # Extract chapter number for sorting
    $chapterNum = if ($file.Name -match 'Chapter_(\d+)') {
        [int]$matches[1]
    } elseif ($file.Name -match 'Chapter_(\d+)[B-]') {
        # Handle Chapter_6B, Chapter_7-1, etc.
        $baseNum = [int]($file.Name -replace '.*Chapter_(\d+).*', '$1')
        $suffix = $file.Name -replace '.*Chapter_\d+([B-].*)', '$1'
        "$baseNum$suffix"
    } else {
        $file.Name
    }
    
    $results += [PSCustomObject]@{
        Chapter = $file.Name
        Number = $chapterNum
        Words = $wordCount
        FileSize = [math]::Round($file.Length / 1KB, 2)
    }
}

# Sort by chapter number (handling numeric and alphanumeric)
$sortedResults = $results | Sort-Object {
    if ($_.Number -match '^\d+$') {
        [int]$_.Number
    } elseif ($_.Number -match '^(\d+)([B-].*)$') {
        [int]$matches[1] * 1000 + ($matches[2] -replace '[^0-9]', '').PadLeft(3, '0')
    } else {
        9999
    }
}

# Display results
$separator = "=" * 80
Write-Host $separator -ForegroundColor Cyan
Write-Host ("{0,-25} {1,10} {2,12}" -f "CHAPTER", "WORDS", "SIZE (KB)") -ForegroundColor Yellow
Write-Host $separator -ForegroundColor Cyan

foreach ($result in $sortedResults) {
    $color = if ($result.Words -lt 2000) { "Red" }
             elseif ($result.Words -lt 3000) { "Yellow" }
             else { "Green" }
    
    Write-Host ("{0,-25} {1,10:N0} {2,12:N2}" -f $result.Chapter, $result.Words, $result.FileSize) -ForegroundColor $color
}

Write-Host $separator -ForegroundColor Cyan
Write-Host ("{0,-25} {1,10:N0} {2,12:N2}" -f "TOTAL", $totalWords, ($results | Measure-Object -Property FileSize -Sum).Sum) -ForegroundColor Green
Write-Host $separator -ForegroundColor Cyan

# Statistics
$avgWords = [math]::Round($totalWords / $totalFiles, 0)
$minWords = ($results | Measure-Object -Property Words -Minimum).Minimum
$maxWords = ($results | Measure-Object -Property Words -Maximum).Maximum

Write-Host "`nSTATISTICS:" -ForegroundColor Cyan
Write-Host "  Total Chapters: $totalFiles" -ForegroundColor White
Write-Host "  Total Words: $totalWords" -ForegroundColor White
Write-Host "  Average Words/Chapter: $avgWords" -ForegroundColor White
Write-Host "  Shortest Chapter: $minWords words" -ForegroundColor White
Write-Host "  Longest Chapter: $maxWords words" -ForegroundColor White

# Estimate book length
$estimatedPages = [math]::Round($totalWords / 250, 0)  # Standard: ~250 words per page
Write-Host "`nESTIMATED BOOK LENGTH:" -ForegroundColor Cyan
Write-Host "  Estimated Pages (250 words/page): $estimatedPages pages" -ForegroundColor White
Write-Host "  Book Status: " -NoNewline -ForegroundColor White

if ($totalWords -lt 50000) {
    Write-Host "Novella/Short Novel" -ForegroundColor Yellow
} elseif ($totalWords -lt 80000) {
    Write-Host "Standard Novel" -ForegroundColor Green
} elseif ($totalWords -lt 110000) {
    Write-Host "Long Novel" -ForegroundColor Green
} else {
    Write-Host "Epic Novel" -ForegroundColor Cyan
}

# Identify chapters that might need attention
Write-Host "`nCHAPTERS NEEDING ATTENTION:" -ForegroundColor Cyan
$shortChapters = $sortedResults | Where-Object { $_.Words -lt 2000 }
$longChapters = $sortedResults | Where-Object { $_.Words -gt 5000 }

if ($shortChapters) {
    Write-Host "  Short chapters (< 2000 words):" -ForegroundColor Yellow
    foreach ($ch in $shortChapters) {
        Write-Host "    - $($ch.Chapter): $($ch.Words) words" -ForegroundColor Yellow
    }
}

if ($longChapters) {
    Write-Host "  Long chapters (> 5000 words):" -ForegroundColor Yellow
    foreach ($ch in $longChapters) {
        Write-Host "    - $($ch.Chapter): $($ch.Words) words" -ForegroundColor Yellow
    }
}

if (-not $shortChapters -and -not $longChapters) {
    Write-Host "  None - all chapters are within optimal range!" -ForegroundColor Green
}

Write-Host "`n" -ForegroundColor White

# Export to CSV for further analysis
$csvPath = "chapter_word_counts_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
$sortedResults | Export-Csv -Path $csvPath -NoTypeInformation
Write-Host "Detailed report exported to: $csvPath" -ForegroundColor Gray

