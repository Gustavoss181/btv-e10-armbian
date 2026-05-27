# btv-e10-armbian

Descaracterização da **TV Box BTV E10** (Amlogic S905X2): remoção do Android nativo e
adaptação de um **Armbian 100% funcional** para uso como servidor / media center.

O coração do projeto é um **device tree customizado** (`meson-g12a-btv-e10.dts`),
derivado do `sei510` de referência da Amlogic, que ensina ao kernel mainline o
hardware específico desta placa — Wi-Fi, LEDs e áudio analógico — que o DTB genérico
não conhece.

> ⚠️ Projeto pessoal, "as-is". O sistema roda a partir de mídia externa (USB/SD);
> a eMMC interna não é tocada nos testes, então rollback é sempre possível
> restaurando o `armbianEnv.txt`. Sem risco de brick enquanto o u-boot/eMMC ficam intactos.

---

## Hardware

| Item | Detalhe |
|------|---------|
| Modelo | BTV E10 (marca BTV / fabricante AB) |
| SoC | Amlogic **S905X2** — família `g12a` |
| DTB base de referência | SEI Robotics SEI510 (`seirobotics,sei510`, `amlogic,g12a`) |
| CPU | 4× ARM Cortex-A53 @ 1000–1800 MHz (aarch64) |
| GPU | ARM **Mali-G31** (driver Panfrost, id `0x7093`) |
| RAM | 2 GB (~1,8 GiB úteis) |
| eMMC interna | `/dev/mmcblk1` ~8 GB (7,2 GiB reais) — **preservada** |
| Mídia de boot | USB/SD externo (`/dev/sda`): `armbi_boot` (vfat) + `armbi_root` (ext4) |
| Ethernet | `eth0` — 100 Mbps Full (meson8b-dwmac, PHY interno G12A) |
| Wi-Fi | `wlan0` — chip SDIO (cartão SDIO em `mmc2`) |
| Saída de vídeo | HDMI (meson-drm / VPU) |
| Áudio | Codec interno **T9015** → Lineout (analógico) |

**Software de referência no momento dos testes:**

- Armbian `26.8.0-trunk.12` (BRANCH `current`, BOARD `aml-s9xx-box`)
- Kernel `6.18.31-current-meson64`

---

## Status do hardware

Legenda: ✅ funcionando · 🟡 parcial / a validar · ⛔ inviável

| Componente | Status | Observação |
|------------|--------|------------|
| Ethernet | ✅ | Sempre funcionou (100 Mbps) |
| HDMI (vídeo) | ✅ | meson-drm OK |
| **Wi-Fi** | ✅ | GPIOs de power-on/IRQ + clock LPO no DTS; removido `sd-uhs-sdr50` |
| **LEDs** | ✅ | Nós portados do DTB do Android; controlados por `.service` |
| **Áudio analógico (Lineout)** | ✅ | Codec T9015 + toacodec + dai-link, roteamento FRDDR→TDMOUT_B→T9015→Lineout, mute via GPIOAO_2 |
| Áudio HDMI | 🟡 | Caminho existe; falta validar em TV com EDID de áudio |
| Decode de vídeo por HW | 🟡 | `meson-vdec` (V4L2) — alto valor, próximo alvo |
| GPU 3D (Panfrost/GLES) | 🟡 | Panfrost já inicializa; falta validar EGL/GLES (`glmark2-es2`) |
| Controle remoto IR | 🟡 | `meson-ir` presente; falta keymap (`ir-keytable`) |
| HDMI-CEC | 🟡 | `ff800280.cec` presente; falta `cec-utils` |
| Bluetooth | ⛔ | Hardware ausente/fechado; nó "fantasma" removido do DTS |
| Câmera | ⛔ | Inexistente (Android já reportava "nenhuma câmera") |
| Telefonia | ⛔ | Inexistente |

Detalhes do que está em estudo: ver [`ROADMAP.md`](ROADMAP.md).

---

## As três famílias de mudança no DTS

Tudo concentrado em `dts/meson-g12a-btv-e10.dts` (diffável contra o `sei510` original):

1. **Wi-Fi** — habilitação do SDIO com GPIOs de power-on/IRQ, clock LPO, e remoção
   do `sd-uhs-sdr50` que impedia a inicialização.
2. **LEDs** — nós portados do DTB do Android (mapeamento real de GPIO/cor da placa).
3. **Áudio analógico** — codec `T9015`, `toacodec`, `dai-link` e roteamento completo
   até o Lineout, com mute automático via `GPIOAO_2`.

Mais a **remoção do nó `bluetooth` fantasma** (hardware não existe nesta placa).

---

## Estrutura do repositório

```
btv-e10-armbian/
├── README.md                  ← este arquivo
├── ROADMAP.md                 ← feito + o que falta testar/ajustar
├── boot/
│   ├── armbianEnv.txt          ← aponta o fdtfile + cmdline (chave do rollback)
│   ├── extlinux.conf
│   └── aml_autoscript
├── dtb/                        ← binários gerados (ver .gitignore)
├── dts/
│   ├── meson-g12a-btv-e10.dts  ← fonte de verdade (customizado)
│   ├── meson-g12a-sei510.dts   ← referência p/ diff
│   └── android_u212_2g.dts     ← DTB do Android decompilado (mapa do hardware)
├── system/
│   └── etc/systemd/system/     ← btv-led-boot.service, btv-led-online.service
├── scripts/
│   ├── initial_config.sh       ← instalador (DTB, services, holds)
│   ├── backup_btv_e10.sh
│   ├── diag.sh
│   └── extract_dtb.py
└── docs/
    ├── diagnostics/            ← relatórios AIDA64 (Android) e diag (Armbian)
    └── references/android/      ← getprop, cpuinfo, partições, etc.
```

> Os `.dtb` são **gerados** a partir do `.dts` — recomendado mantê-los no `.gitignore`
> e marcar cada milestone funcional como uma **tag** git (`v1-led-ok`, `v2-wifi-ok`,
> `v3-sound-ok`) em vez de arquivos `.bak`.

---

## Build e instalação

Pré-requisito: `device-tree-compiler` (`dtc`).

```bash
# 1) Compilar o DTB a partir do DTS customizado
dtc -I dts -O dtb -o dtb/meson-g12a-btv-e10.dtb dts/meson-g12a-btv-e10.dts

# 2) Instalar na mídia de boot (exemplos)
#    - localmente, com o pendrive montado:
cp dtb/meson-g12a-btv-e10.dtb /media/$USER/armbi_boot/dtb/amlogic/
#    - ou na box via SSH:
scp dtb/meson-g12a-btv-e10.dtb root@<ip-da-box>:/boot/dtb/amlogic/

# 3) Apontar o fdtfile em boot/armbianEnv.txt
#    fdtfile=amlogic/meson-g12a-btv-e10.dtb

# 4) Reiniciar e conferir
dmesg | grep -iE 'panfrost|wlan|t9015|led|error|fail'
```

Os `.service` dos LEDs e os holds de pacote são aplicados pelo
`scripts/initial_config.sh` (faz `cp`, `systemctl daemon-reload` e
`systemctl enable --now`).

### Persistência do áudio

O mute é resolvido no device tree, mas o **volume** depende do estado salvo do mixer:

```bash
alsactl store
```

### Proteção contra upgrade sobrescrever o DTB

```bash
sudo apt-mark hold armbian-bsp-cli-aml-s9xx-box-current
```

---

## Rollback

O sistema vive na mídia externa, então reverter é trivial:

1. Montar a partição `armbi_boot` num PC (ou acessar via SSH).
2. Restaurar o `armbianEnv.txt` apontando para o DTB de referência
   (`meson-g12a-sei510.dtb`) ou um `.dtb` de milestone anterior.
3. Reiniciar.

Nenhuma operação toca o u-boot ou a eMMC interna.

---

## Privacidade

Antes de tornar o repositório público, mascarar identificadores nos arquivos de
`docs/`:

- `docs/references/android/getprop.txt` — `ro.serialno` / `ro.boot.serialno` (serial
  do SoC), `ro.boot.mac` (MAC Ethernet), `persist.netd.stable_secret` (segredo IPv6).
- Relatórios de diagnóstico — MAC, IPv6 globais e serial do SoC.

Em repositório **privado** isso é menos crítico, mas convém mascarar antes do primeiro
commit para não deixar os dados no histórico do git.

---

## Roadmap (resumo)

**Feito:** Wi-Fi · LEDs · áudio analógico · Ethernet · HDMI vídeo.

**Em estudo (ordem sugerida para media center):**
decode de vídeo por HW (`meson-vdec`/V4L2) → IR remoto → HDMI-CEC → validar Panfrost.

**Inviável:** Bluetooth · câmera · telefonia.

Lista completa e detalhada em [`ROADMAP.md`](ROADMAP.md).

---

## Referências

- DTB de referência: `meson-g12a-sei510` (kernel mainline Amlogic g12a)
- Armbian para caixas Amlogic: `aml-s9xx-box`
- DTB do Android (decompilado) como mapa do hardware da placa
