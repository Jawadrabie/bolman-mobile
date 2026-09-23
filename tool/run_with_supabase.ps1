param(
  [string]$DeviceId = ""
)

$ErrorActionPreference = "Stop"

$argsList = @(
  "run",
  "--dart-define=SUPABASE_URL=https://uvwzdbpisgxvasfkchbu.supabase.co",
  "--dart-define=SUPABASE_ANON_KEY=sb_publishable_CwdlJmaAudGKhp-6ZcATBg_absL391D"
)

if ($DeviceId -ne "") {
  $argsList += @("-d", $DeviceId)
}

flutter @argsList

