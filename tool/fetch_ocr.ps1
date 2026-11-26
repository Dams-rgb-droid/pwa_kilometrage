# Télécharge les fichiers OCR (Tesseract.js) dans web/ocr.
# À lancer UNE FOIS, à la racine du projet :  powershell -ExecutionPolicy Bypass -File tool\fetch_ocr.ps1
$ErrorActionPreference = 'Continue'
$dest = Join-Path $PSScriptRoot '..\web\ocr'
New-Item -ItemType Directory -Force -Path $dest, (Join-Path $dest 'lang') | Out-Null

$files = @(
  @('https://cdn.jsdelivr.net/npm/tesseract.js@5.1.1/dist/tesseract.min.js',            'tesseract.min.js'),
  @('https://cdn.jsdelivr.net/npm/tesseract.js@5.1.1/dist/worker.min.js',               'worker.min.js'),
  @('https://cdn.jsdelivr.net/npm/tesseract.js-core@5.1.1/tesseract-core.wasm.js',           'tesseract-core.wasm.js'),
  @('https://cdn.jsdelivr.net/npm/tesseract.js-core@5.1.1/tesseract-core-simd.wasm.js',      'tesseract-core-simd.wasm.js'),
  @('https://cdn.jsdelivr.net/npm/tesseract.js-core@5.1.1/tesseract-core-lstm.wasm.js',      'tesseract-core-lstm.wasm.js'),
  @('https://cdn.jsdelivr.net/npm/tesseract.js-core@5.1.1/tesseract-core-simd-lstm.wasm.js', 'tesseract-core-simd-lstm.wasm.js'),
  @('https://tessdata.projectnaptha.com/4.0.0_fast/eng.traineddata.gz',                      'lang\eng.traineddata.gz')
)
foreach ($f in $files) {
  $out = Join-Path $dest $f[1]
  try {
    Invoke-WebRequest -Uri $f[0] -OutFile $out -UseBasicParsing
    Write-Host ("OK      " + $f[1] + "  (" + [math]::Round((Get-Item $out).Length / 1KB) + " Ko)")
  } catch {
    Write-Host ("ECHEC   " + $f[1] + " : " + $_.Exception.Message) -ForegroundColor Red
  }
}
Write-Host "Terminé. Relancez ensuite flutter build web."
