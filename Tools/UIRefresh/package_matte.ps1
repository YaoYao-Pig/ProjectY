$ErrorActionPreference='Stop'
$reviewRoot=(Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../../Art/UIRefresh/2026-10-25/matte')).Path
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.IO.Compression.FileSystem
$source=[System.Drawing.Bitmap]::new((Join-Path $reviewRoot 'native/mission.png'))
try {$crop=$source.Clone([System.Drawing.Rectangle]::new(408,328,500,152),[System.Drawing.Imaging.PixelFormat]::Format32bppArgb);try {$crop.Save((Join-Path $reviewRoot 'native/rewards-detail.png'),[System.Drawing.Imaging.ImageFormat]::Png)}finally{$crop.Dispose()}}finally{$source.Dispose()}
$paths=@('index.html','README.txt','BRIEF.txt','preservation-check.json','native-import-settings.json') | ForEach-Object {Join-Path $reviewRoot $_}
$paths+=@(Get-ChildItem -LiteralPath (Join-Path $reviewRoot 'native') -File -Recurse | ForEach-Object {$_.FullName})
foreach($name in @('guild','collage','rewards')){
    $dir=Join-Path $reviewRoot $name
    $null=Get-Content -LiteralPath (Join-Path $dir 'manifest.json') -Raw | ConvertFrom-Json
    $paths+=@('manifest.json','components.png') | ForEach-Object {Join-Path $dir $_}
    foreach($extra in @('detail-comparison.png','qa-light-dark-64px.png','paper_surface.png','leather_surface.png','ink_surface.png')){$p=Join-Path $dir $extra;if(Test-Path -LiteralPath $p){$paths+=$p}}
    $slices=@(Get-ChildItem -LiteralPath (Join-Path $dir 'slices') -File -Filter '*.png')
    $expected=if($name -eq 'rewards'){8}else{16}
    if($slices.Count -ne $expected){throw ('Slice count mismatch: '+$name)}
    $paths+=@($slices | ForEach-Object {$_.FullName})
}
$zipPath=Join-Path $reviewRoot 'ProjectY-Matte-UI.zip'
$stream=[System.IO.File]::Create($zipPath);$archive=[System.IO.Compression.ZipArchive]::new($stream,[System.IO.Compression.ZipArchiveMode]::Create)
try {foreach($file in $paths){$entry=[System.IO.Path]::GetRelativePath($reviewRoot,$file).Replace('\','/');[System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive,$file,$entry,[System.IO.Compression.CompressionLevel]::Optimal) | Out-Null}}
finally{$archive.Dispose();$stream.Dispose()}
[pscustomobject]@{Archive=$zipPath;Entries=$paths.Count;Bytes=(Get-Item -LiteralPath $zipPath).Length}
