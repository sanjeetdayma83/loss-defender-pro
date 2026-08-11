# scripts/idor-smoke.ps1 — run against local/staging with TWO company tokens
param(
  [string]$Base = "http://localhost:3000/api/v1",
  [string]$TokenA,   # Company A owner JWT
  [string]$TokenB,   # Company B owner JWT
  [string]$OrderIdB  # An order ID that belongs to Company B
)

$hA = @{ Authorization = "Bearer $TokenA" }
$fails = 0

function ExpectFail($name, $script) {
  try {
    & $script | Out-Null
    Write-Host "FAIL $name — expected 403/404 but succeeded" -ForegroundColor Red
    $script:fails++
  } catch {
    $code = $_.Exception.Response.StatusCode.value__
    if ($code -in 401,403,404) {
      Write-Host "PASS $name ($code)" -ForegroundColor Green
    } else {
      Write-Host "FAIL $name — got $code" -ForegroundColor Red
      $script:fails++
    }
  }
}

ExpectFail "A cannot GET B order" {
  Invoke-RestMethod "$Base/orders/$OrderIdB" -Headers $hA
}
ExpectFail "A cannot PATCH B order" {
  Invoke-RestMethod "$Base/orders/$OrderIdB" -Method PATCH -Headers $hA -ContentType application/json -Body '{"notes":"hack"}'
}

Write-Host "`nIDOR fails: $fails"
if ($fails -gt 0) { exit 1 }
