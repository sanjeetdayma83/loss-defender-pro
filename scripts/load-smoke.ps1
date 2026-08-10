param(
  [int]$N = 30,
  [string]$Base = "http://localhost:3000/api/v1"
)

$ErrorActionPreference = "Continue"
$login = Invoke-RestMethod "$Base/auth/login" -Method POST -ContentType application/json `
  -Body '{"email":"owner2@test.ldp","password":"Test@12345"}'
$h = @{ Authorization = "Bearer $($login.data.accessToken)" }

$ok = 0; $fail = 0
$sw = [System.Diagnostics.Stopwatch]::StartNew()
1..$N | ForEach-Object {
  try {
    Invoke-RestMethod "$Base/orders?take=5" -Headers $h | Out-Null
    $script:ok++
  } catch { $script:fail++ }
}
$sw.Stop()
Write-Host "LOAD N=$N ok=$ok fail=$fail elapsedMs=$($sw.ElapsedMilliseconds) avgMs=$([int]($sw.ElapsedMilliseconds / [math]::Max($N,1)))"
