
$json = Get-Content 'last_call.txt' -Raw
$obj = ConvertFrom-Json $json
$chunks = $obj.tool_calls[0].args.ReplacementChunks
if ($chunks -is [string]) {
    $chunks = $chunks | ConvertFrom-Json
}
$content = Get-Content 'e:\BharatFlow\BharatFlow\lib\features\dashboard\presentation\screens\weather_impact_screen.dart' -Raw
foreach ($c in $chunks) {
    $content = $content.Replace($c.TargetContent, $c.ReplacementContent)
}
Set-Content -Path 'e:\BharatFlow\BharatFlow\lib\features\dashboard\presentation\screens\weather_impact_screen.dart' -Value $content
Write-Output 'Success2!'

