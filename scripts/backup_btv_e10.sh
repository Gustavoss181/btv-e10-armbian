#!/bin/bash
#
# Script de backup completo da TV Box BTV E10 (Amlogic franklin)
# Autor: gerado para o projeto pessoal de Linux em TV Box
#
# Uso: ./backup_btv_e10.sh
#
# Pré-requisitos:
#   - adb instalado e a box conectada (adb connect <IP>:5555)
#   - root funcionando via 'echo comando | su' na box
#   - espaço livre suficiente no destino (~10 GB com folga)
#

set -e  # Aborta no primeiro erro

# Diretório de destino dos backups
BACKUP_DIR="$(pwd)/btv_e10_backup_$(date +%Y%m%d_%H%M%S)"
PARTITIONS_DIR="$BACKUP_DIR/partitions"
LOG_FILE="$BACKUP_DIR/backup.log"

# Função utilitária para rodar comando como root na box
run_as_root() {
    adb shell "echo '$1' | su"
}

# Função para fazer backup de uma partição via dd
backup_partition() {
    local part_name="$1"
    local block_path="$2"
    local output_file="$PARTITIONS_DIR/${part_name}.img"
    
    echo "[+] Fazendo backup de $part_name ($block_path)..."
    echo "[+] Backup: $part_name -> $output_file" >> "$LOG_FILE"
    
    # dd com bs=1048576 (1MB em bytes - Toybox não aceita sufixos como '1M')
    # stderr é redirecionado para não poluir o arquivo de saída
    adb shell "echo 'dd if=$block_path bs=1048576 2>/dev/null' | su" > "$output_file"
    
    # Verifica tamanho do arquivo gerado
    local size=$(stat -c%s "$output_file" 2>/dev/null || echo 0)
    if [ "$size" -eq 0 ]; then
        echo "    ⚠ ATENÇÃO: $part_name ficou com 0 bytes!"
        echo "    ⚠ ATENÇÃO: $part_name ficou com 0 bytes!" >> "$LOG_FILE"
    else
        echo "    ✓ $(numfmt --to=iec-i --suffix=B $size)"
        echo "    OK: $size bytes" >> "$LOG_FILE"
        # Calcula hash SHA256 para verificação posterior
        sha256sum "$output_file" >> "$BACKUP_DIR/SHA256SUMS"
    fi
}

# ============================================================================
# Início
# ============================================================================

echo "=========================================="
echo "  Backup da TV Box BTV E10 (Amlogic)"
echo "=========================================="
echo ""

# Verifica se adb está disponível
if ! command -v adb &> /dev/null; then
    echo "ERRO: adb não está instalado. Instale com: sudo apt install adb"
    exit 1
fi

# Verifica se a box está conectada
if ! adb devices | grep -q "device$"; then
    echo "ERRO: Nenhum dispositivo ADB conectado."
    echo "Use: adb connect <IP_DA_BOX>:5555"
    exit 1
fi

# Cria diretórios
mkdir -p "$PARTITIONS_DIR"
echo "Backup iniciado em: $(date)" > "$LOG_FILE"
echo "Diretório de backup: $BACKUP_DIR"
echo ""

# ============================================================================
# Coleta informações do sistema antes do backup
# ============================================================================

echo "[1/3] Coletando informações do sistema..."

run_as_root "cat /proc/partitions" > "$BACKUP_DIR/partitions.txt"
run_as_root "ls -la /dev/block/platform/*/by-name/" > "$BACKUP_DIR/partition_names.txt"
run_as_root "cat /proc/cpuinfo" > "$BACKUP_DIR/cpuinfo.txt"
run_as_root "cat /proc/meminfo" > "$BACKUP_DIR/meminfo.txt"
run_as_root "cat /proc/cmdline" > "$BACKUP_DIR/cmdline.txt"
run_as_root "getprop" > "$BACKUP_DIR/getprop.txt"
run_as_root "mount" > "$BACKUP_DIR/mount.txt"
run_as_root "cat /proc/mtd" > "$BACKUP_DIR/mtd.txt" 2>/dev/null || true

echo "    ✓ Informações salvas"
echo ""

# ============================================================================
# Backup das partições
# ============================================================================

echo "[2/3] Fazendo backup das partições..."
echo ""

# Limpa o arquivo de hashes
> "$BACKUP_DIR/SHA256SUMS"

# Bootloaders e áreas especiais (CRÍTICAS - ficam fora da eMMC principal)
backup_partition "mmcblk0boot0" "/dev/block/mmcblk0boot0"
backup_partition "mmcblk0boot1" "/dev/block/mmcblk0boot1"

# Partições do sistema (na ordem em que aparecem em mmcblk0pN)
backup_partition "logo"       "/dev/block/logo"
backup_partition "recovery"   "/dev/block/recovery"
backup_partition "rsv"        "/dev/block/rsv"
backup_partition "tee"        "/dev/block/tee"
backup_partition "cri_data"   "/dev/block/cri_data"
backup_partition "param"      "/dev/block/param"
backup_partition "boot"       "/dev/block/boot"
backup_partition "dtbo"       "/dev/block/dtbo"
backup_partition "misc"       "/dev/block/misc"
backup_partition "metadata"   "/dev/block/metadata"
backup_partition "reserved"   "/dev/block/reserved"
backup_partition "env"        "/dev/block/env"
backup_partition "vbmeta"     "/dev/block/vbmeta"
backup_partition "odm"        "/dev/block/odm"
backup_partition "product"    "/dev/block/product"
backup_partition "vendor"     "/dev/block/vendor"
backup_partition "system"     "/dev/block/system"
backup_partition "cache"      "/dev/block/cache"
backup_partition "data"       "/dev/block/data"

echo ""
echo "[3/3] Fazendo backup completo da eMMC (mmcblk0)..."
echo "    Este é o backup mais importante (~7.3 GB), pode demorar 20-40 min..."
backup_partition "mmcblk0_FULL" "/dev/block/mmcblk0"

# ============================================================================
# Finalização
# ============================================================================

echo ""
echo "=========================================="
echo "  Backup concluído!"
echo "=========================================="
echo "Local: $BACKUP_DIR"
echo "Tamanho total:"
du -sh "$BACKUP_DIR"
echo ""
echo "Arquivos gerados:"
ls -lh "$PARTITIONS_DIR"
echo ""
echo "Backup finalizado em: $(date)" >> "$LOG_FILE"
echo "Log completo em: $LOG_FILE"
