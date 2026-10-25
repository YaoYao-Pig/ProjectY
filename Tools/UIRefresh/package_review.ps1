$ErrorActionPreference='Stop'
$reviewRoot=(Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../../Art/UIRefresh/2026-10-25')).Path
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.IO.Compression.FileSystem
$canvas=[System.Drawing.Bitmap]::new(3840,1632)
$g=[System.Drawing.Graphics]::FromImage($canvas)
$font=[System.Drawing.Font]::new('Microsoft YaHei',30,[System.Drawing.FontStyle]::Bold)
$brush=[System.Drawing.SolidBrush]::new([System.Drawing.ColorTranslator]::FromHtml('#eae6db'))
$background=[System.Drawing.SolidBrush]::new([System.Drawing.ColorTranslator]::FromHtml('#202d30'))
$names=@('inventory','skills','mission','dialogue','event')
$titles=@('08 · 背包 / 原生组装','08 · 技艺 / 原生组装','09 · 任务 / 原生组装','09 · 对话 / 原生组装','09 · 事件 / 原生组装','32 张透明控件切图')
try {
    $g.Clear([System.Drawing.ColorTranslator]::FromHtml('#101719'))
    $g.InterpolationMode=[System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.TextRenderingHint=[System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
    for($i=0;$i -lt 6;$i++){
        $x=($i%3)*1280+12;$y=[math]::Floor($i/3)*816+12
        $g.FillRectangle($background,$x,$y,1256,792)
        $g.DrawString($titles[$i],$font,$brush,$x+18,$y+12)
        if($i -lt 5){
            $source=[System.Drawing.Image]::FromFile((Join-Path $reviewRoot ('native/'+$names[$i]+'.png')))
            try {$g.DrawImage($source,[System.Drawing.Rectangle]::new($x+8,$y+76,1240,698))} finally {$source.Dispose()}
        } else {
            $kits=@('guild-clean','collage-clean')
            for($k=0;$k -lt 2;$k++){
                $source=[System.Drawing.Image]::FromFile((Join-Path $reviewRoot ($kits[$k]+'/components.png')))
                try {$g.DrawImage($source,[System.Drawing.Rectangle]::new($x+12+($k*620),$y+115,610,610))} finally {$source.Dispose()}
            }
        }
    }
    $canvas.Save((Join-Path $reviewRoot 'native-overview.jpg'),[System.Drawing.Imaging.ImageFormat]::Jpeg)
} finally {$g.Dispose();$canvas.Dispose();$font.Dispose();$brush.Dispose();$background.Dispose()}
$paths=@('index.html','README.txt','BRIEF.txt','native-overview.jpg','applied-assets.json','preservation-check.json') | ForEach-Object {Join-Path $reviewRoot $_}
$paths+=@(Get-ChildItem -LiteralPath (Join-Path $reviewRoot 'native') -File | ForEach-Object {$_.FullName})
foreach($kit in @('guild-clean','collage-clean')){
    $kitRoot=Join-Path $reviewRoot $kit
    $null=Get-Content -LiteralPath (Join-Path $kitRoot 'manifest.json') -Raw | ConvertFrom-Json
    $paths+=@('components.png','manifest.json') | ForEach-Object {Join-Path $kitRoot $_}
    $paths+=@(Get-ChildItem -LiteralPath $kitRoot -File -Filter '*-concept.png' | ForEach-Object {$_.FullName})
    $slices=@(Get-ChildItem -LiteralPath (Join-Path $kitRoot 'slices') -File -Filter '*.png')
    if($slices.Count -ne 16){throw ('Missing slices: '+$kit)}
    $paths+=@($slices | ForEach-Object {$_.FullName})
}
$zipPath=Join-Path $reviewRoot 'ProjectY-Clean-UI.zip'
$stream=[System.IO.File]::Create($zipPath)
$archive=[System.IO.Compression.ZipArchive]::new($stream,[System.IO.Compression.ZipArchiveMode]::Create)
try {
    foreach($file in $paths){$entry=[System.IO.Path]::GetRelativePath($reviewRoot,$file).Replace('\','/');[System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive,$file,$entry,[System.IO.Compression.CompressionLevel]::Optimal) | Out-Null}
} finally {$archive.Dispose();$stream.Dispose()}
[pscustomobject]@{Archive=$zipPath;Files=$paths.Count;Bytes=(Get-Item -LiteralPath $zipPath).Length}
