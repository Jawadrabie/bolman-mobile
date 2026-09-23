@echo off
setlocal

set SUPABASE_URL=https://uvwzdbpisgxvasfkchbu.supabase.co
set SUPABASE_ANON_KEY=sb_publishable_CwdlJmaAudGKhp-6ZcATBg_absL391D

if "%~1"=="" (
  flutter run --dart-define=SUPABASE_URL=%SUPABASE_URL% --dart-define=SUPABASE_ANON_KEY=%SUPABASE_ANON_KEY%
) else (
  flutter run -d %1 --dart-define=SUPABASE_URL=%SUPABASE_URL% --dart-define=SUPABASE_ANON_KEY=%SUPABASE_ANON_KEY%
)

endlocal

