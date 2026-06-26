param(
  [Parameter(Mandatory = $true)]
  [string]$ServerHost,

  [string]$ServerUser = "root",
  [string]$Domain = "koneksi.co.id",

  [Parameter(Mandatory = $true)]
  [string]$SupabaseUrl,

  [Parameter(Mandatory = $true)]
  [string]$SupabaseAnonKey,

  [string]$AppEnv = "production"
)

$ErrorActionPreference = "Stop"

$releaseId = Get-Date -Format "yyyyMMddHHmmss"
$archiveName = "kaswarga-$releaseId.zip"
$archivePath = Join-Path $env:TEMP $archiveName
$remoteArchive = "/tmp/$archiveName"
$remoteRelease = "/var/www/$Domain/releases/$releaseId"
$remoteCurrent = "/var/www/$Domain/current"

Write-Host "Membangun Flutter Web release..."
flutter build web --release `
  --dart-define=SUPABASE_URL=$SupabaseUrl `
  --dart-define=SUPABASE_ANON_KEY=$SupabaseAnonKey `
  --dart-define=APP_ENV=$AppEnv

if (Test-Path $archivePath) {
  Remove-Item $archivePath -Force
}

Write-Host "Membuat arsip $archivePath..."
Compress-Archive -Path "build/web/*" -DestinationPath $archivePath -Force

Write-Host "Mengunggah arsip ke $ServerUser@$ServerHost..."
scp $archivePath "$ServerUser@$ServerHost`:$remoteArchive"

$remoteCommand = @"
set -e
sudo mkdir -p "$remoteRelease"
sudo unzip -oq "$remoteArchive" -d "$remoteRelease"
sudo ln -sfn "$remoteRelease" "$remoteCurrent"
sudo chown -R www-data:www-data "/var/www/$Domain"
sudo nginx -t
sudo systemctl reload nginx
rm -f "$remoteArchive"
"@

Write-Host "Mengaktifkan release di server..."
ssh "$ServerUser@$ServerHost" $remoteCommand

Write-Host "Deploy selesai: https://$Domain"
