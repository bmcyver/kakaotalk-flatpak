#!/usr/bin/env bash
set -euo pipefail

case "${1:-}" in
  --setup) setup=true; shift ;;
  --help)
    echo 'Usage: flatpak run com.kakao.KakaoTalk [--setup|--help]'
    echo 'First launch automatically installs dependencies and opens KakaoTalk_Setup.exe.'
    echo '--setup opens the installer again for repair.'
    exit 0 ;;
  '') setup=false ;;
  *) echo 'Unknown option. Use --help.' >&2; exit 2 ;;
esac
if (( $# )); then
  echo 'Unexpected arguments. Use --help.' >&2
  exit 2
fi

export WINEPREFIX="${XDG_DATA_HOME:?}/wine"
export WINEARCH=win64
export WINEDEBUG=-all
export WINEESYNC=0 WINEFSYNC=0 WINENTSYNC=0
export WINEDLLOVERRIDES='winemenubuilder.exe=d'
export W_CACHE="${XDG_CACHE_HOME:?}/winetricks"
app_dir=/app/share/kakaotalk
state_dir="${XDG_DATA_HOME}/kakaotalk"

find_executable() {
  local candidate
  for candidate in \
    "$WINEPREFIX/drive_c/Program Files (x86)/Kakao/KakaoTalk/KakaoTalk.exe" \
    "$WINEPREFIX/drive_c/Program Files/Kakao/KakaoTalk/KakaoTalk.exe"; do
    if [[ -f $candidate ]]; then
      executable=$candidate
      return 0
    fi
  done
  return 1
}

mkdir -p "$state_dir"
exec 9>"$state_dir/lock"
if ! flock -n 9; then
  echo 'KakaoTalk or setup is already running.' >&2
  exit 1
fi

# Use X11 for existing prefixes, including those used for Wayland experiments.
wine reg add 'HKCU\Software\Wine\Drivers' /v Graphics /t REG_SZ /d x11 /f > /dev/null
wineserver -w

if [[ $setup == false ]] && ! find_executable; then
  setup=true
fi

if [[ $setup == true ]]; then
  echo 'Setting up KakaoTalk: installing Windows dependencies and opening the installer.'
  (cd "$app_dir" && sha256sum --check KakaoTalk_Setup.exe.sha256)
  if [[ ! -f "$state_dir/dependencies-complete" ]]; then
    wineboot --init
    wineserver -w
    winetricks --unattended win10 arial times courier cjkfonts gdiplus riched20 vcrun2019
    winetricks --unattended win10
    wine regedit /S "$app_dir/kakaotalk.reg"
    wineserver -w
    touch "$state_dir/dependencies-complete"
  fi
  wine "$app_dir/KakaoTalk_Setup.exe"
  wineserver -w
  if ! find_executable; then
    echo 'KakaoTalk was not installed in the default location. Run --setup again and use the default path.' >&2
    exit 1
  fi
  echo 'Setup complete. Starting KakaoTalk.'
fi

if ! find_executable; then
  echo 'KakaoTalk.exe is missing. Run: flatpak run com.kakao.KakaoTalk --setup' >&2
  exit 1
fi
if [[ -f "$state_dir/dependencies-complete" ]]; then
  rm -rf -- "$W_CACHE"
fi
cd "$(dirname "$executable")"
wine "$executable"
wineserver -w
