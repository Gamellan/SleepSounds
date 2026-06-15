Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$audioDir = Join-Path $root 'assets\audio'
New-Item -ItemType Directory -Force -Path $audioDir | Out-Null

$sampleRate = 22050
$seconds = 30
$totalSamples = $sampleRate * $seconds

function Write-Wav {
    param(
        [string]$Path,
        [int]$SampleRate,
        [double[]]$Data
    )

    $numChannels = 1
    $bitsPerSample = 16
    $byteRate = $SampleRate * $numChannels * ($bitsPerSample / 8)
    $blockAlign = $numChannels * ($bitsPerSample / 8)
    $dataSize = $Data.Length * 2
    $chunkSize = 36 + $dataSize

    $fs = [System.IO.File]::Open($Path, [System.IO.FileMode]::Create)
    $bw = New-Object System.IO.BinaryWriter($fs)

    $bw.Write([System.Text.Encoding]::ASCII.GetBytes('RIFF'))
    $bw.Write([int]$chunkSize)
    $bw.Write([System.Text.Encoding]::ASCII.GetBytes('WAVE'))
    $bw.Write([System.Text.Encoding]::ASCII.GetBytes('fmt '))
    $bw.Write([int]16)
    $bw.Write([int16]1)
    $bw.Write([int16]$numChannels)
    $bw.Write([int]$SampleRate)
    $bw.Write([int]$byteRate)
    $bw.Write([int16]$blockAlign)
    $bw.Write([int16]$bitsPerSample)
    $bw.Write([System.Text.Encoding]::ASCII.GetBytes('data'))
    $bw.Write([int]$dataSize)

    foreach ($v in $Data) {
        $clamped = [Math]::Max(-1.0, [Math]::Min(1.0, $v))
        $sample = [int16]([Math]::Round($clamped * 32767.0))
        $bw.Write($sample)
    }

    $bw.Close()
    $fs.Close()
}

function New-WhiteNoise {
    $arr = New-Object double[] $totalSamples
    for ($i = 0; $i -lt $totalSamples; $i++) {
        $arr[$i] = ((Get-Random -Minimum -10000 -Maximum 10001) / 10000.0) * 0.25
    }
    return $arr
}

function Smooth {
    param([double[]]$data, [double]$alpha)
    $out = New-Object double[] $data.Length
    $prev = 0.0
    for ($i = 0; $i -lt $data.Length; $i++) {
        $prev = $alpha * $prev + (1 - $alpha) * $data[$i]
        $out[$i] = $prev
    }
    return $out
}

$white = New-WhiteNoise
Write-Wav -Path (Join-Path $audioDir 'white_noise.wav') -SampleRate $sampleRate -Data $white

$rain = Smooth -data $white -alpha 0.90
Write-Wav -Path (Join-Path $audioDir 'rain.wav') -SampleRate $sampleRate -Data $rain

$ocean = Smooth -data $white -alpha 0.97
for ($i = 0; $i -lt $ocean.Length; $i++) {
    $mod = 0.65 + 0.35 * [Math]::Sin(2 * [Math]::PI * ($i / $sampleRate) / 5.0)
    $ocean[$i] *= $mod
}
Write-Wav -Path (Join-Path $audioDir 'ocean.wav') -SampleRate $sampleRate -Data $ocean

$forest = Smooth -data $white -alpha 0.94
for ($i = 0; $i -lt $forest.Length; $i++) {
    $t = $i / $sampleRate
    $chirp = 0.06 * [Math]::Sin(2 * [Math]::PI * (1200 + 50 * [Math]::Sin($t * 0.8)) * $t)
    $forest[$i] = $forest[$i] * 0.8 + $chirp
}
Write-Wav -Path (Join-Path $audioDir 'forest.wav') -SampleRate $sampleRate -Data $forest

$fan = New-Object double[] $totalSamples
for ($i = 0; $i -lt $fan.Length; $i++) {
    $t = $i / $sampleRate
    $hum = 0.15 * [Math]::Sin(2 * [Math]::PI * 90 * $t)
    $hiss = (((Get-Random -Minimum -10000 -Maximum 10001) / 10000.0) * 0.08)
    $fan[$i] = $hum + $hiss
}
$fan = Smooth -data $fan -alpha 0.92
Write-Wav -Path (Join-Path $audioDir 'fan.wav') -SampleRate $sampleRate -Data $fan

Write-Output "Generated WAV files in $audioDir"
