# Contexto do projeto — BTV E10 / Armbian

Atualizado em **17/10/2026**. Ponto de retomada para Gustavo e Codex em novas
conversas. Reúne as decisões da conversa, a leitura do repositório e o diagnóstico
SSH de 16/10/2026. As observações da box são um retrato daquela sessão; devem ser
revalidadas antes de depender delas para uma mudança.

## Objetivo atual

Transformar a TV Box em **servidor pessoal ligado 24 horas por dia**, para hospedar
fotos com armazenamento externo, controlar a lâmpada do quarto, executar APIs de
projetos pessoais e atender outros usos domésticos.

O destino desejado é **Armbian na eMMC interna**, com armazenamento externo para
dados e serviços. Gustavo considera pendrive ou cartão SD, inclusive a possibilidade
de mover `/home`. A disposição dos dados e o software dos serviços ainda não foram
definidos. A migração para a eMMC **ainda não foi realizada**.

Preservar o Android deixou de ser requisito. O README e o ROADMAP ainda refletem
o objetivo anterior, com maior foco em media center e preservação da eMMC.
Estabilidade, armazenamento, recuperação e manutenção passam a ter prioridade;
aceleração gráfica, IR, CEC e áudio são objetivos secundários.

## Histórico e método de trabalho

Gustavo começou o projeto em outro notebook, com ajuda do Claude, e o retomou
com o Codex depois de um período parado.

O Android original foi mantido como referência: comparar o que funcionava nele e
decompilar seu DTB ajudou a identificar GPIOs, conexões e parâmetros específicos
da placa que os DTBs genéricos não descreviam corretamente.

Fluxo usado: **decompilar DTB → estudar DTS → ajustar DTS do Armbian → compilar
com `dtc` → instalar o DTB → testar no aparelho**. Esse trabalho permitiu ajustar
Wi-Fi, LEDs, áudio AV/HDMI e outros detalhes. A correspondência entre o DTS salvo
no Git e o DTB hoje instalado ainda precisa ser verificada, pois parte do trabalho
aconteceu no outro notebook.

## Hardware e arquivos principais

- **BTV E10**, SoC Amlogic **S905X2 / G12A**, quatro Cortex-A53, 2 GB de RAM
  (aproximadamente 1,8 GiB disponíveis), GPU Mali-G31.
- eMMC nominal de 8 GB; observada como `/dev/mmcblk1`, aproximadamente 7,1 GiB.
  Identificar novamente o dispositivo antes de qualquer operação de armazenamento.
- Ethernet de 100 Mbps; Wi-Fi SDIO com driver **`rtl8189fs`**, confirmado na box.
- Codec analógico **T9015**. Bluetooth foi tratado como ausente ou sem suporte
  aproveitável no trabalho anterior; o nó herdado do SEI510 foi removido.

| Caminho | Papel |
| --- | --- |
| `dts/meson-g12a-btv-e10.dts` | DTS customizado do Armbian, derivado do SEI510 |
| `dts/meson-g12a-sei510.dts` | Referência para comparar as adaptações |
| `dts/android_u212_2g.dts` | DTB do Android decompilado, referência do hardware |
| `boot/` | Cópias das configurações e do script de boot |
| `system/etc/systemd/system/` | Serviços `net-led.service` e `sys-led-ready.service` |
| `scripts/backup_btv_e10.sh` | Coleta e backup do Android via ADB/root |
| `scripts/extract_dtb.py` | Extrai componentes de um `boot.img` Android |
| `scripts/diag.sh` | Coleta diagnóstico do Armbian |
| `docs/diagnostics/` | Diagnósticos históricos do Android e do Armbian |
| `docs/references/android/` | Informações, log e hashes do backup Android |
| `pictures/` | Fotos do aparelho e da placa |

As alterações no DTS incluem ajustes de alimentação/reset e velocidade do SDIO,
LEDs com GPIOs da placa, habilitação do T9015 e do caminho de áudio analógico,
mute via GPIOAO_2 e remoção do nó Bluetooth herdado.

## Estado observado por SSH

| Item | Observação em 16/10/2026 |
| --- | --- |
| Sistema | Debian 13 / trixie; `/etc/os-release` anuncia Armbian `26.8.0-trunk.42` |
| Metadados Armbian | `/etc/armbian-release` ainda informa `26.8.0-trunk.12`; imagem `nightly` |
| Kernel | `6.18.32-current-meson64` |
| Mídia em uso | USB `/dev/sda`, aproximadamente 14,9 GiB |
| Raiz | `/dev/sda2`, ext4, label `armbi_root`; cerca de 1,4 GiB usados e 13 GiB livres |
| Boot | `/dev/sda1`, FAT, label `armbi_boot`, montado em `/boot` |
| eMMC | `/dev/mmcblk1`, com `boot0`/`boot1`; sem montagem aparente |
| Memória | Cerca de 236 MiB usados; swap em zram, sem uso na leitura |
| Temperatura | CPU 45,8 °C; DDR 46,5 °C; sem teste prolongado de carga |
| Rede | `wlan0` ativa; `eth0` sem link; a sessão SSH depende do Wi-Fi |
| DTB configurado | `amlogic/meson-g12a-btv-e10.dtb` nos dois arquivos de boot |
| Modelo anunciado | Ainda `SEI Robotics SEI510` |
| LEDs personalizados | `net-led.service` e `sys-led-ready.service` ativos |
| Serviço com falha | `armbian-led-state.service`; causa ainda não investigada |
| Proteção de pacotes | Holds em `armbian-bsp-cli-aml-s9xx-box-current` e `linux-dtb-current-meson64` |

Existem DTBs anteriores no diretório de boot. O binário customizado foi encontrado
em `/boot/dtb/amlogic/meson-g12a-btv-e10.dtb`. Ainda não comparamos seu conteúdo
com o DTS do repositório. Os holds foram confirmados, mas não validamos todo o
comportamento do sistema durante atualizações.

## Funcionalidades: evidência e pendências

- **Documentadas como funcionando:** Ethernet, vídeo HDMI, Wi-Fi, LEDs e áudio
  analógico. Nesta retomada, confirmamos a conexão Wi-Fi e os serviços de LEDs;
  não repetimos todos os testes funcionais.
- **Áudio HDMI:** Gustavo relatou ajustes no fluxo anterior, mas a documentação
  ainda marca a validação como pendente. Confirmar se chegou a ser testado.
- **Panfrost:** dispositivos DRM e `renderD128` presentes; desempenho e EGL/GLES
  ainda não foram validados nesta retomada.
- **Vídeo por hardware, IR e HDMI-CEC:** pendências do roadmap antigo, sem novos
  testes. Não são pré-requisitos definidos para o servidor pessoal.
- Ainda faltam testes de operação prolongada, retorno após queda de energia,
  armazenamento externo e recuperação de falhas.

## Acesso para continuar

- SSH na rede local: **`codex@192.168.15.12:22`**.
- Usuário exclusivo `codex`, membro do grupo `sudo`, com login por chave confirmado.
- Chave local usada: `/home/gustavo/.ssh/id_ed25519`. Não copiar seu conteúdo
  para a conversa ou para o Git. A senha foi definida por Gustavo fora do chat.
- Nesta sessão, foi necessário usar `-F /dev/null` devido a um erro de proprietário
  ou permissões na configuração SSH global do ambiente de execução.
- O sandbox exigiu autorização de rede para SSH. Isso é independente do `sudo`
  dentro da box.
- `sudo -n -l` respondeu que precisa de senha. A forma de elevação administrativa
  ainda precisa ser definida, sem compartilhar a senha na conversa.
- O usuário não conseguiu ler o journal do sistema por falta de permissões.

Exemplo de consulta, a partir deste notebook:

```bash
ssh -i /home/gustavo/.ssh/id_ed25519 -F /dev/null \
  -o BatchMode=yes -o ConnectTimeout=8 -o StrictHostKeyChecking=yes \
  codex@192.168.15.12 'id; uname -r; uptime'
```

O histórico comum do Bash não registra automaticamente todos os comandos SSH
não interativos. Manter neste repositório as decisões, mudanças e procedimentos
relevantes, além dos registros administrativos disponíveis no sistema.

## Divergências conhecidas no repositório

1. `boot/armbianEnv.txt` e `boot/extlinux.conf` apontam para **`.dts`**, enquanto
   os arquivos consultados na box apontam corretamente para **`.dtb`**.
2. O README cita `scripts/initial_config.sh`, mas esse arquivo não existe.
3. Nomes e arquivos de LEDs do README/ROADMAP foram atualizados em 17/10/2026;
   ver a seção de sincronização abaixo.
4. A confirmação dos holds já foi feita na box, mas continua pendente no ROADMAP.
5. O objetivo de servidor com instalação interna ainda precisa ser incorporado
   aos documentos antigos.

`dtc` não foi encontrado no PATH deste notebook durante a inspeção inicial.
Os `.dtb` são artefatos gerados e estão ignorados pelo Git. O diretório `dtb/`
pode precisar ser criado antes da compilação documentada no README.

## Próxima sequência proposta

1. Comparar o DTB instalado e as configurações/serviços da box com os arquivos
   do Git; verificar se há material adicional no outro notebook.
2. Definir a elevação administrativa e investigar a falha do serviço de LEDs.
3. Conferir a localização, integridade e utilidade dos backups Android. Há log e
   hashes no Git; a disponibilidade dos binários e o processo de restauração
   ainda não foram verificados nesta retomada.
4. Consolidar build, instalação, configuração e recuperação reproduzíveis.
5. Planejar e executar a migração para a eMMC depois de identificar o procedimento
   adequado à placa e preservar uma cópia funcional do sistema atual.
6. Definir armazenamento externo, backups e serviços; validar o uso contínuo.

Até a criação deste resumo, o Codex realizou apenas consultas na box. Não houve
instalação de pacotes, alteração de configurações, reinicialização ou escrita na
eMMC pelo Codex. Gustavo criou o usuário e instalou a chave pública pelo terminal.

## Retomada de 17/10/2026 — LEDs e sincronização

Gustavo reforçou que os LEDs são essenciais para diagnóstico sem monitor nem
teclado, especialmente na perda do SSH. A configuração instalada de LEDs foi
copiada para `system/`: os dois serviços, `/usr/local/bin/update-net-led.sh` e
quatro hooks de `networkd-dispatcher`. Os links dos hooks usam caminhos relativos
no checkout; seu conteúdo corresponde ao instalado. README e ROADMAP foram
corrigidos quanto aos nomes e comportamento desses componentes.

NET atualmente acende por carrier em `eth0` OU `wlan0`. Não verifica IP ou SSH.
SYS passa de heartbeat para fixo quando seu serviço inicia. Na consulta, Wi-Fi
estava conectado, NET aceso, SYS em `default-on` e SSH escutando na porta 22.

O parser da restauração padrão do Armbian rejeita valores vazios existentes em
`/etc/armbian-leds.conf` (como `link_100=`), explicando a falha do serviço. Ainda
não houve correção na box nem acesso ao journal do sistema.

O objetivo para NET é piscar durante busca/reconexão e ficar fixo após confirmar
rede local e resposta estável do SSH. Vermelho para falha depende de identificar
os canais físicos. O DTS Android contém PWM `red`, `green`, `blue` e GPIO de IR,
mas o Armbian só expõe SYS e NET com estados 0/1; as cores e a ligação dos cinco
LEDs visíveis nas fotos da placa ainda não foram mapeadas. Indicar sessões SSH
ativas foi considerado possivelmente redundante, sem decisão de implementar.

Detalhes, proposta e procedimento de reinstalação: `docs/leds.md`. Nesta etapa,
somente o repositório foi alterado; nenhuma configuração da box foi modificada.
