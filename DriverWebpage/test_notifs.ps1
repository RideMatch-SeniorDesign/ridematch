$headers = @{
  "Content-Type" = "application/json"
  "X-Internal-Key" = "change-this-key"
}

$body = @{
  event = "ride_request_received"
  payload = @{
    target_role = "driver"
    account_id = 3
    title = "New ride request"
    message = "Terminal test popup"
  }
} | ConvertTo-Json -Depth 5

Invoke-RestMethod -Method POST -Uri "http://127.0.0.1:8002/internal/notify" -Headers $headers -Body $body