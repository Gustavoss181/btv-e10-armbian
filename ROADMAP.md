# Roadmap — BTV E10 / Armbian

Estado das funcionalidades e próximos alvos. Atualizar conforme cada item for
validado na imagem real.

---

## ✅ Feito / funcionando

Mudanças permanentes já aplicadas no `meson-g12a-btv-e10.dts` e no sistema:

- [x] **Ethernet** — 100 Mbps Full (funcionou desde o início, sem mudança no DTS).
- [x] **HDMI (vídeo)** — meson-drm / VPU OK.
- [x] **Wi-Fi** — SDIO habilitado: GPIOs de power-on/IRQ, clock LPO, remoção do
      `sd-uhs-sdr50`. Interface `wlan0` sobe e conecta.
- [x] **LEDs** — nós portados do DTB do Android (GPIO/cor reais da placa),
      controlados pelos serviços `btv-led-boot` e `btv-led-online`.
- [x] **Áudio analógico (Lineout)** — codec `T9015` + `toacodec` + `dai-link`,
      roteamento `FRDDR → TDMOUT_B → T9015 → Lineout`, mute automático via `GPIOAO_2`.
- [x] **Remoção do nó `bluetooth` fantasma** — hardware inexistente nesta placa.

> Lembrete de persistência: rodar `alsactl store` após ajustar o volume (o mute vem
> do device tree, mas o nível de mixer depende do estado salvo).

---

## 🟡 Em estudo / a testar e ajustar

Do mais viável/maior retorno ao mais incerto. Ordem sugerida para uso como
**media center**: decode de vídeo → IR → CEC → Panfrost.

### 1. Decode de vídeo por hardware (VPU) — alto valor, viável
O Android expõe um arsenal de decoders Amlogic por HW (H.264, HEVC, VP9, etc. via
`OMX.amlogic.*`). No mainline isso corresponde ao `meson-vdec` (aparece no dmesg como
módulo da staging directory). Meta: decode acelerado de H.264/HEVC/VP9 via V4L2.
- Testar com `mpv --hwdec=v4l2m2m` e/ou Kodi com `--gbm`.
- Observação: aqui é só **decode**; encode por HW é incerto no mainline.

### 2. Controle remoto IR — viável
Android reporta `android.hardware.consumerir`; dmesg mostra `meson-ir registered`.
- Configurar keymap com `ir-keytable` para o controle físico da box voltar a funcionar.

### 3. HDMI-CEC — viável
`ff800280.cec` presente no dmesg.
- Instalar `cec-utils` e validar controle da box pelo controle da própria TV.

### 4. GPU 3D (Mali-G31 via Panfrost) — viável, meio caminho andado
Panfrost já inicializa (`renderD128` presente).
- Instalar `mesa` com Panfrost e validar EGL/GLES com `glmark2-es2`.
- Ganho: interface gráfica fluida / Kodi.

### 5. Áudio HDMI — provavelmente pronto
O caminho HDMI existe; não foi possível testar sem um sink com EDID de áudio.
- Validar direto numa TV.

---

## ⛔ Inviável / não vale a pena

- **Bluetooth** — sem hardware (ou módulo fechado); nó fantasma já removido do DTS.
- **Câmera** — inexistente (Android já reportava "nenhuma câmera").
- **Telefonia** — inexistente (`Tipo de Telefone: Nenhum`).

---

## 📌 Pendências de manutenção

- [ ] Confirmar `apt-mark hold` no pacote BSP
      (`armbian-bsp-cli-aml-s9xx-box-current`) — **crítico** para um `apt upgrade`
      não sobrescrever o DTB customizado.
- [ ] Marcar tags git por milestone (`v1-led-ok`, `v2-wifi-ok`, `v3-sound-ok`) em vez
      de manter arquivos `.bak` de DTB/DTS.
- [ ] Mascarar identificadores sensíveis em `docs/` antes de publicar.

### Lixo de diagnóstico — NÃO recriar na imagem limpa

Itens que existiram só durante o processo e não devem entrar na imagem final:

- `/etc/modules-load.d/bluetooth-btv.conf` e `/etc/modprobe.d/bluetooth-btv.conf`
  (já removidos).
- `echo 8 > /proc/sys/kernel/printk` foi temporário — remover se ficou em algum
  lugar permanente.
- Backups `.bak` de DTB/DTS espalhados.

---

> Próximo passo a definir: escolher o primeiro alvo da seção "Em estudo".
> Um `REBUILD.md` (checklist ordenada "do flash à imagem funcional") complementa
> bem este roadmap quando for reconstruir a imagem definitiva.
