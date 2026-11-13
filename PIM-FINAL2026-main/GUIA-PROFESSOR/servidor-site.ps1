# Servidor simples para o site (pasta "aplicacao web"). Nao precisa instalar nada.
# Uso: powershell -File servidor-site.ps1 -Root "<pasta do site>" [-Port 5500]
param(
    [Parameter(Mandatory = $true)][string]$Root,
    [int]$Port = 5500,
    [switch]$SemNavegador
)

$ErrorActionPreference = "Stop"
$Root = (Resolve-Path -LiteralPath $Root).Path

$tipos = @{
    ".html" = "text/html; charset=utf-8"; ".htm" = "text/html; charset=utf-8"
    ".js" = "application/javascript; charset=utf-8"; ".css" = "text/css; charset=utf-8"
    ".json" = "application/json; charset=utf-8"; ".txt" = "text/plain; charset=utf-8"
    ".png" = "image/png"; ".jpg" = "image/jpeg"; ".jpeg" = "image/jpeg"; ".gif" = "image/gif"
    ".svg" = "image/svg+xml"; ".ico" = "image/x-icon"; ".webp" = "image/webp"
    ".woff" = "font/woff"; ".woff2" = "font/woff2"; ".mp4" = "video/mp4"
}

# A API so aceita o site nas portas 5500 e 5501: tenta uma e depois a outra.
$listener = $null
foreach ($p in @($Port, 5501)) {
    try {
        $l = New-Object System.Net.HttpListener
        $l.Prefixes.Add("http://localhost:$p/")
        $l.Start()
        $listener = $l
        $Port = $p
        break
    } catch {
        Write-Host "Porta $p ocupada, tentando a proxima..."
    }
}
if (-not $listener) {
    Write-Host "ERRO: as portas 5500 e 5501 estao ocupadas. Feche o que as usa e tente de novo."
    exit 1
}

$url = "http://localhost:$Port/index.html"
Write-Host ""
Write-Host "SITE NO AR: $url"
Write-Host "Deixe esta janela aberta. Para parar, feche a janela (ou Ctrl+C)."
Write-Host ""
if (-not $SemNavegador) { Start-Process $url }

try {
    while ($listener.IsListening) {
        $ctx = $listener.GetContext()
        $res = $ctx.Response
        try {
            $caminho = [System.Uri]::UnescapeDataString($ctx.Request.Url.AbsolutePath).TrimStart("/")
            if ([string]::IsNullOrEmpty($caminho)) { $caminho = "index.html" }
            $arquivo = [System.IO.Path]::GetFullPath((Join-Path $Root $caminho))
            # impede sair da pasta do site
            if (-not $arquivo.StartsWith($Root, [System.StringComparison]::OrdinalIgnoreCase)) {
                $res.StatusCode = 403
            } elseif (-not (Test-Path -LiteralPath $arquivo -PathType Leaf)) {
                $res.StatusCode = 404
            } else {
                $ext = [System.IO.Path]::GetExtension($arquivo).ToLower()
                $res.ContentType = if ($tipos.ContainsKey($ext)) { $tipos[$ext] } else { "application/octet-stream" }
                $bytes = [System.IO.File]::ReadAllBytes($arquivo)
                $res.ContentLength64 = $bytes.Length
                $res.OutputStream.Write($bytes, 0, $bytes.Length)
            }
        } catch {
            $res.StatusCode = 500
        } finally {
            $res.Close()
        }
    }
} finally {
    $listener.Stop()
}
