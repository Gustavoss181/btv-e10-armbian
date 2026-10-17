# LEDs de diagnóstico da BTV E10

Inspeção em 17/10/2026, por SSH e pelas fotos em `pictures/`. Objetivo: permitir
diagnóstico externo da box sem monitor nem teclado, principalmente quando o SSH
não estiver acessível.

## Configuração instalada e copiada para o repositório

Os caminhos abaixo são relativos a `/` na box e a `system/` no repositório:

| Arquivo | Função |
| --- | --- |
| `etc/systemd/system/net-led.service` | Remove o trigger anterior e calcula o estado inicial do NET no boot |
| `usr/local/bin/update-net-led.sh` | Acende NET se `eth0/carrier` ou `wlan0/carrier` for `1`; apaga caso contrário |
| `etc/networkd-dispatcher/carrier.d/10-net-led` | Chama o script quando há mudança de estado |
| `etc/networkd-dispatcher/{no-carrier,off,routable}.d/10-net-led` | Mesmo hook nos demais estados configurados |
| `etc/systemd/system/sys-led-ready.service` | Troca SYS para `default-on` ao iniciar e para `heartbeat` ao parar |

Serviços, script e conteúdo dos quatro hooks foram lidos diretamente da box.
Na box, os três links apontam para o caminho absoluto do hook em `carrier.d`.
No repositório, usam `../carrier.d/10-net-led`, para funcionar também no checkout.
O script e o hook principal precisam manter permissão executável.

O serviço NET é `oneshot`: o acompanhamento posterior depende do
`networkd-dispatcher`, ativo na inspeção. Não há consulta periódica de saúde.
O trigger atual de NET é `none`; o script escreve diretamente em `brightness`.
Não há indicação de tráfego nem de sessões SSH.

O Device Tree define SYS inicialmente ligado com trigger `heartbeat` e NET
inicialmente desligado. SYS fixo indica a execução do serviço de sinalização;
não é um monitor contínuo da saúde dos serviços.

Na inspeção, `wlan0` tinha endereço IPv4 e carrier `1`, `eth0` estava sem carrier,
NET tinha brightness `1` e SYS estava em `default-on`. O SSH estava ativo e
escutando na porta 22. Não foram simuladas quedas nem realizados testes visuais.

## O que sabemos das cores e dos GPIOs

O Device Tree em execução expõe dois LEDs `gpio-leds`, ambos com
`max_brightness=1`, sem atributos de seleção de cor:

| Controle | Banco / offset | Origem no Android |
| --- | --- | --- |
| `btv:status:sys` | AO / 11 (`GPIOAO_11`) | `gpioleds/sys_led` |
| `btv:status:net` | AO / 4 (`GPIOAO_4`) | `ledindicator_params/net_led-gpio` |

Os GPIOs desses dois nós em execução coincidem com os do DTS customizado do Git.
Isso não equivale a uma comparação completa do DTB instalado com o repositório.
O nome `btv:status:net` é um rótulo e não oferece um comando para trocar cores.

Em `dts/android_u212_2g.dts`, também existem:

- `ledindicator_params/ir_led-gpio`: controlador de GPIOs periféricos, offset
  `0x16` (22). A numeração do kernel Android não deve ser transposta para o
  mainline sem verificar o mapeamento do banco.
- `pwmleds`, habilitado no DTS, com canais chamados `red`, `green` e `blue`,
  cada um com PWM e `max-brightness=255`. São pistas de configuração, não
  comprovação de que três cores estejam conectadas neste modelo de placa.

A foto frontal mostra POWER e NET verdes e IR vermelho. As fotos `leds.jpg` e
`leds_1.jpg` mostram cinco encapsulamentos de LED em grupos de dois, dois e um.
Não é possível determinar pela foto a cor de cada componente, seu GPIO ou se
os canais são independentes, complementares ou misturados por guia de luz.
A correspondência entre SYS e POWER também precisa de teste visual.

A cor depende dos componentes e de como estão ligados à placa. DTS e driver
descrevem quais canais o Linux consegue acionar; rótulos de cor não criam
capacidade física. O controle atual permite ligar/desligar e usar padrões de
pisca, mas não fornece seleção explícita de vermelho/verde.

Referências: [classe de LEDs](https://www.kernel.org/doc/html/latest/leds/leds-class.html)
e [LEDs multicoloridos](https://www.kernel.org/doc/html/latest/leds/leds-class-multicolor.html).

## Proposta para NET — ainda não implementada

| Estado | Padrão proposto |
| --- | --- |
| Inicialização, busca ou reconexão | Pisca lento |
| Rede utilizável e SSH respondendo de forma estável | Aceso fixo |
| Falha persistente de rede ou SSH | Vermelho, se o canal for identificado; alternativamente, dois flashes seguidos de pausa |

Reservar o padrão de falha até depois de um período de tentativa evita confundir
o boot normal com defeito. A estabilidade deve exigir várias verificações
consecutivas; os tempos ainda precisam ser definidos. A proposta não representa
as cores ou padrões já instalados na box.

A verificação deve considerar a mesma interface com enlace, endereço utilizável,
acesso à rede local e resposta do protocolo SSH. A ausência de internet não
deve apagar a indicação de acesso local. Apenas verificar `ssh.service` ativo ou
a porta aberta é insuficiente para assegurar que o servidor responde.
Mesmo um teste local de protocolo não comprova acesso a partir do notebook:
firewall, isolamento da rede e autenticação ainda podem impedir o login.

Não há decisão de adicionar um padrão para sessões SSH ativas; o usuário
considerou que essa indicação pode ser redundante.

## Falha da restauração de LEDs do Armbian

`armbian-led-state.service` falhou ao iniciar. Seu arquivo de estado
`/etc/armbian-leds.conf` guarda a configuração antiga de NET com trigger `netdev`
e campos vazios, começando por `link_100=`. O script de restauração inspecionado
rejeita valores vazios e sai com erro. O journal do sistema não estava acessível
ao usuário `codex`; a causa foi identificada pela leitura do arquivo e do parser.

Os serviços personalizados iniciaram depois e aplicaram o estado atual. Ainda
é necessário corrigir a persistência e evitar que múltiplos serviços disputem
os mesmos LEDs. Nenhuma correção foi aplicada na box nesta sincronização.

## Reinstalação da configuração atual

Para executar na box, a partir da raiz deste repositório. Isto reinstala o
comportamento de carrier, sem a proposta de indicação de SSH:

```sh
sudo apt-get install networkd-dispatcher
sudo install -m 0755 system/usr/local/bin/update-net-led.sh /usr/local/bin/
sudo install -m 0644 system/etc/systemd/system/net-led.service /etc/systemd/system/
sudo install -m 0644 system/etc/systemd/system/sys-led-ready.service /etc/systemd/system/
for state in carrier no-carrier off routable; do
    sudo install -d "/etc/networkd-dispatcher/$state.d"
    sudo install -m 0755 "system/etc/networkd-dispatcher/$state.d/10-net-led" "/etc/networkd-dispatcher/$state.d/10-net-led"
done
sudo systemctl daemon-reload
sudo systemctl enable --now networkd-dispatcher.service
sudo systemctl enable net-led.service sys-led-ready.service
sudo systemctl restart net-led.service sys-led-ready.service
```

Pré-requisito: Device Tree com os nós `btv:status:sys` e `btv:status:net`.
Os comandos de reinstalação não foram executados nesta inspeção.
