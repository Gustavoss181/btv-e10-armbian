#!/bin/bash
#
# diag-btv-e10.sh — Diagnóstico estruturado da TV Box BTV E10 (Amlogic S905X2)
# rodando Armbian. Coleta hardware, armazenamento, rede, vídeo, Wi-Fi/BT e boot.
#
# Uso:
#   chmod +x diag-btv-e10.sh
#   sudo ./diag-btv-e10.sh                 # mostra na tela E salva em arquivo
#   sudo ./diag-btv-e10.sh -q              # só salva no arquivo (silencioso)
#   sudo ./diag-btv-e10.sh -o /caminho.txt # define o arquivo de saída
#
# A saída é salva com timestamp para você comparar execuções ao longo do tempo

set -u

# ---------- configuração / argumentos ----------
QUIET=0
OUT=""
while [ $# -gt 0 ]; do
  case "$1" in
    -q|--quiet) QUIET=1 ;;
    -o|--output) shift; OUT="${1:-}" ;;
    -h|--help)
      grep '^#' "$0" | sed 's/^# \{0,1\}//' | head -20
      exit 0 ;;
    *) echo "Argumento desconhecido: $1" >&2; exit 1 ;;
  esac
  shift
done

# arquivo de saída padrão: ~/diag-btv-e10_AAAAMMDD_HHMMSS.txt
if [ -z "$OUT" ]; then
  TS="$(date +%Y%m%d_%H%M%S)"
  # tenta o home do usuário real mesmo sob sudo
  HOME_DIR="${SUDO_USER:+/home/$SUDO_USER}"
  [ -d "$HOME_DIR" ] || HOME_DIR="$HOME"
  OUT="$HOME_DIR/diag-btv-e10_${TS}.txt"
fi

# avisa se não está como root (vários comandos precisam)
if [ "$(id -u)" -ne 0 ]; then
  echo "AVISO: rodando sem root — alguns dados (fdisk, dmesg, lshw) podem faltar."
  echo "       Recomendado: sudo $0"
  echo
fi

# ---------- infraestrutura de saída ----------
# Tudo é escrito no arquivo; se não for quiet, também ecoa na tela.
emit() {
  if [ "$QUIET" -eq 0 ]; then
    tee -a "$OUT"
  else
    cat >> "$OUT"
  fi
}

# roda um comando rotulado. Uso: run "rótulo" comando args...
run() {
  local label="$1"; shift
  {
    echo "### $label"
    echo "\$ $*"
    if command -v "${1%% *}" >/dev/null 2>&1 || [ -e "${1}" ]; then
      "$@" 2>&1 || echo "[comando retornou erro $?]"
    else
      echo "[comando indisponível: $1]"
    fi
    echo
  } | emit
}

# seção com cabeçalho visível
section() {
  {
    echo
    echo "============================================================"
    echo "  $1"
    echo "============================================================"
  } | emit
}

# ---------- início ----------
: > "$OUT"   # zera/ cria o arquivo
{
  echo "Relatório de diagnóstico — BTV E10 (Amlogic S905X2)"
  echo "Gerado em: $(date)"
  echo "Host: $(hostname)  |  Kernel: $(uname -r)  |  Usuário: $(whoami)"
} | emit

# ---------- 1. Identificação ----------
section "1. IDENTIFICAÇÃO DO SISTEMA"
run "Modelo (device-tree)" sh -c "cat /proc/device-tree/model 2>/dev/null; echo"
run "Compatível (DTB)"     sh -c "cat /proc/device-tree/compatible 2>/dev/null | tr '\0' '\n'; echo"
run "DTB em uso (armbianEnv)" sh -c "grep -i fdtfile /boot/armbianEnv.txt 2>/dev/null || echo 'armbianEnv.txt não encontrado'"
run "Versão Armbian"       sh -c "cat /etc/armbian-release 2>/dev/null | grep -iE 'version|board|branch' || echo n/d"
run "Uptime"               uptime

# ---------- 2. CPU ----------
section "2. PROCESSADOR"
run "lscpu" lscpu
run "Frequências por núcleo" sh -c "for c in /sys/devices/system/cpu/cpu[0-9]*/cpufreq/scaling_cur_freq; do [ -f \"\$c\" ] && echo \"\$c: \$(cat \$c) kHz\"; done"

# ---------- 3. Memória ----------
section "3. MEMÓRIA"
run "free -h" free -h
run "swap" swapon --show

# ---------- 4. Armazenamento (o ponto-chave: tamanho REAL da eMMC) ----------
section "4. ARMAZENAMENTO"
run "lsblk (visão geral)" lsblk -o NAME,SIZE,TYPE,FSTYPE,LABEL,MOUNTPOINT
run "Tamanho real de cada disco" sh -c "for d in /dev/mmcblk[0-9] /dev/sd[a-z]; do [ -b \"\$d\" ] && echo \"\$d: \$(lsblk -bdno SIZE \$d 2>/dev/null | numfmt --to=iec) (\$(lsblk -bdno SIZE \$d 2>/dev/null) bytes)\"; done"
run "Partições detalhadas (fdisk)" sh -c "fdisk -l /dev/mmcblk[0-9] /dev/sd[a-z] 2>/dev/null"
run "Uso de espaço montado" df -h -x tmpfs -x devtmpfs
# Detecção da eMMC interna: é a mmcblkX que TEM mmcblkXboot0/boot1 associados.
run "Identificar eMMC interna (tem boot0/boot1)" sh -c '
  for dev in /sys/block/mmcblk[0-9]; do
    n=$(basename "$dev")
    if [ -e "/dev/${n}boot0" ]; then
      sz=$(lsblk -bdno SIZE "/dev/$n" 2>/dev/null | numfmt --to=iec)
      echo "eMMC interna = /dev/$n  (tamanho real: $sz)"
    fi
  done
  echo "Nota: a mídia SEM boot0/boot1 e removível costuma ser o SD/pendrive."
'

# ---------- 5. Rede ----------
section "5. REDE"
run "Interfaces" ip -br link show
run "Endereços IP" ip -br addr show
run "Ethernet (link)" sh -c "dmesg 2>/dev/null | grep -iE 'dwmac|eth0' | tail -10"

# ---------- 6. Wi-Fi e Bluetooth (historicamente problemáticos nesta box) ----------
section "6. WI-FI E BLUETOOTH"
run "Interfaces Wi-Fi (iw)" sh -c "iw dev 2>/dev/null || echo 'iw não disponível / sem interface wlan'"
run "rfkill" sh -c "rfkill list 2>/dev/null || echo n/d"
run "SDIO / Wi-Fi no dmesg" sh -c "dmesg 2>/dev/null | grep -iE 'sdio|mmc2|wifi|wlan|brcm|rtl|ampak|error -84' | tail -20"
run "Bluetooth no dmesg" sh -c "dmesg 2>/dev/null | grep -iE 'bluetooth|hci|bcm' | tail -15"

# ---------- 7. Vídeo / GPU (erros de flip_done observados) ----------
section "7. VÍDEO / GPU"
run "Dispositivos DRM" sh -c "ls -l /dev/dri/ 2>/dev/null"
run "GPU (panfrost/mali)" sh -c "dmesg 2>/dev/null | grep -iE 'panfrost|mali|lima' | tail -10"
run "Erros de display (meson-drm)" sh -c "dmesg 2>/dev/null | grep -iE 'meson-drm|flip_done|vblank|vpu' | tail -15"

# ---------- 8. Temperatura ----------
section "8. TEMPERATURA"
run "Zonas térmicas" sh -c '
  for z in /sys/class/thermal/thermal_zone*; do
    [ -f "$z/temp" ] || continue
    t=$(cat "$z/temp"); type=$(cat "$z/type" 2>/dev/null)
    printf "%-24s %s°C\n" "$type" "$(awk "BEGIN{printf \"%.1f\", $t/1000}")"
  done
'

# ---------- 9. Boot / u-boot (relevante para o projeto eMMC) ----------
section "9. BOOT E PARTIÇÃO DE BOOT"
run "Conteúdo de /boot" sh -c "ls -la /boot/ 2>/dev/null | head -30"
run "armbianEnv.txt" sh -c "cat /boot/armbianEnv.txt 2>/dev/null"
run "extlinux.conf" sh -c "cat /boot/extlinux/extlinux.conf 2>/dev/null"
run "cmdline ativa" sh -c "cat /proc/cmdline"
run "Pacotes de boot segurados (hold)" sh -c "apt-mark showhold 2>/dev/null | grep -iE 'u-boot|bsp' || echo 'nenhum hold relacionado a boot'"

# ---------- 10. Resumo de erros do kernel ----------
section "10. RESUMO DE ERROS DO KERNEL"
run "Erros/falhas/avisos (dmesg)" sh -c "dmesg 2>/dev/null | grep -iE 'error|fail|warn' | grep -ivE 'staging directory' | head -25"

# ---------- encerramento ----------
{
  echo
  echo "============================================================"
  echo "  FIM DO RELATÓRIO"
  echo "============================================================"
  echo "Salvo em: $OUT"
} | emit

# garante permissão pro usuário real (não root) abrir o arquivo
if [ -n "${SUDO_USER:-}" ]; then
  chown "$SUDO_USER" "$OUT" 2>/dev/null || true
fi

# mensagem final sempre na tela
echo
echo ">> Relatório salvo em: $OUT"
