# Girar o display da MKS Pi (Neptune 3 / KlipperScreen) para Portrait

Guia para aplicar a rotação de tela que foi testada e confirmada nesta máquina
(acesso via `ssh mks@192.168.3.201`, senha `makerbase`).

## Resumo

- Tela: 3,5" resistiva, controlador SPI `ilitek,st7796` (driver `fb_st7796`/`fbtft`), framebuffer físico fixo em **480x320**.
- O `rotate` do device tree (`/boot/dtb/rockchip/rk3328-mkspi.dtb`) **não resolve** — nesse driver ele só espelha a imagem 180°, não troca largura/altura. Não precisa (e não deve) ser alterado para isto. Ele deve permanecer no valor original (`rotate = <90>;`).
- A rotação real para Portrait é feita em duas camadas:
  1. **Xorg** (driver `fbdev`, que usa shadow framebuffer) — gira a tela via `Option "Rotate"`.
  2. **Touchscreen** (`ADS7846 Touchscreen`, via `xinput`) — precisa de uma "Coordinate Transformation Matrix" compatível com a rotação escolhida, senão o toque não acompanha a tela.

## Passo a passo

1. Conectar via SSH:
   ```
   ssh mks@192.168.3.201
   ```

2. Editar `/etc/X11/xorg.conf.d/02-driver.conf` para incluir a opção de rotação no driver `fbdev`:
   ```
   # set fbdev as default driver.
   Section "Device"
            Identifier "NOGPU"
            Driver "fbdev"
            Option "Rotate" "CW"
   EndSection
   ```
   - `"CW"` = sentido horário (foi o valor que ficou correto nesta instalação).
   - `"CCW"` giraria no sentido anti-horário (testamos primeiro e ficou invertido em relação ao desejado).
   - `"UD"` (upside down) e remover a opção (normal) também são válidos, caso precise no futuro.

3. Copiar o script [touchscreen-fix.sh](touchscreen-fix.sh) (versão corrigida, mantida aqui no projeto) para `/usr/local/bin/touchscreen-fix.sh` no dispositivo — é o script chamado após o KlipperScreen iniciar (ver `ExecStartPost` em `KlipperScreen.service`), responsável por aplicar a matriz de transformação do touch:
   ```
   pscp touchscreen-fix.sh mks@192.168.3.201:/tmp/touchscreen-fix.sh
   ssh mks@192.168.3.201 "sudo install -m 755 -o root -g root /tmp/touchscreen-fix.sh /usr/local/bin/touchscreen-fix.sh"
   ```
   A versão original (encontrada já instalada, não faz parte de nenhum projeto oficial) só continha `sleep 5` antes de rodar o `xinput`, o que é uma corrida contra o início do Xorg/touch — podia falhar dependendo da demora do boot. A versão corrigida espera ativamente o dispositivo `ADS7846 Touchscreen` aparecer (até 30s) antes de aplicar a matriz. Se precisar trocar a orientação, edite as variáveis `MATRIX` (e `DEVICE`, se o nome do touch mudar) dentro do script — veja a tabela abaixo para os valores de cada orientação.

5. Reiniciar a placa para aplicar (a troca de `Option "Rotate"` do Xorg exige reinício do X/KlipperScreen; reiniciar a placa é o jeito mais simples e seguro):
   ```
   sudo reboot
   ```
   Antes de reiniciar, confirme que não há impressão em andamento (`curl -s http://localhost:7125/printer/objects/query?print_stats`, campo `state` deve ser `standby`).

6. Depois do boot, validar:
   ```
   DISPLAY=:0 xrandr
   ```
   deve mostrar `320x480` como resolução atual (Portrait).
   ```
   DISPLAY=:0 xinput list-props "ADS7846 Touchscreen" | grep -A1 "Coordinate Transformation"
   ```
   deve mostrar a matriz `0.000000, -1.000000, 1.000000, -1.000000, 0.000000, 1.000000, 0.000000, 0.000000, 1.000000`.
   Testar tocando nos cantos da tela (um botão no topo e outro no rodapé da UI) para confirmar que o toque acompanha o que é mostrado.

## Se precisar girar para o outro lado (ou desfazer)

Troque apenas os dois valores abaixo (sem tocar no device tree) e reinicie:

| Orientação desejada | `Option "Rotate"` | Matriz do touch (`xinput set-prop ... Coordinate Transformation Matrix`) |
|---|---|---|
| Landscape original (sem rotação) | *(remover a linha `Option "Rotate"`)* | `1 0 0 0 1 0 0 0 1` |
| Portrait girado à direita (usado aqui) | `CW` | `0 -1 1 -1 0 1 0 0 1` |
| Portrait girado à esquerda | `CCW` | `0 1 0 1 0 0 0 0 1` |
| Landscape de cabeça para baixo | `UD` | `1 0 0 0 -1 1 0 0 1` (igual ao original, com Y invertido) |

## Arquivos envolvidos

- `/etc/X11/xorg.conf.d/02-driver.conf` — driver de vídeo e rotação.
- `/usr/local/bin/touchscreen-fix.sh` — matriz de calibração/rotação do touch, chamado pelo `KlipperScreen.service` via `ExecStartPost`. **Não faz parte do KlipperScreen nem do armbian-mkspi** (não existe em nenhum dos dois repositórios) — é um script próprio desta instalação. Versão corrigida e testada (espera ativa pelo dispositivo de touch, em vez de `sleep` fixo) mantida aqui no projeto: [touchscreen-fix.sh](touchscreen-fix.sh) — é essa a versão que deve ser copiada para o dispositivo. A versão original com `sleep 5` foi deixada como backup em `/usr/local/bin/touchscreen-fix.sh.orig.bak` no próprio dispositivo.
- `/boot/dtb/rockchip/rk3328-mkspi.dtb` — **não precisa alterar**; mantém `rotate = <90>;` original (há um backup em `rk3328-mkspi.dtb.pre-portrait.bak` caso algo precise ser restaurado).

## Versões instaladas no dispositivo (referência)

Levantado em 2026-10-31 via SSH:

- **Placa / SO**: Armbian-unofficial, board `mkspi` (rockchip64, SoC RK3328), branch `edge`.
  `VERSION=26.02.0-trunk`, `REVISION=26.02.0-trunk`, `BUILD_REPOSITORY_COMMIT=ed9707196-dirty` (`/etc/armbian-release`).
- **Kernel**: `6.18.3-edge-rockchip64`.
- **Board support (device tree, drivers do painel/touch)**: projeto [redrathnure/armbian-mkspi](https://github.com/redrathnure/armbian-mkspi).
  A versão `26.02.0-trunk` corresponde à série de tags `v26.2.0-trunk.*` desse repositório (ex.: `v26.2.0-trunk.890`, de 2026-04-19 — a mais recente dessa série). O hash exato `ed9707196` não corresponde a um commit desse repositório especificamente (não foi encontrado na busca pelo histórico completo); ele é o commit do **orquestrador de build do Armbian** usado para gerar a imagem, não do repositório `armbian-mkspi` em si (que entra como overlay/board-support dentro do build). A série mais nova disponível no repositório hoje é `v26.8.0-trunk.*` (ex.: `v26.8.0-trunk.424`, de 2026-07-27) — ou seja, este dispositivo está numa branch de trunk mais antiga que a atual.
- **Servidor X11**: `xserver-xorg-core 2:21.1.7-3+deb12u11`, driver de vídeo `xserver-xorg-video-fbdev 1:0.5.0-2` (usa shadow framebuffer, por isso aceita `Option "Rotate"`), driver de entrada `xserver-xorg-input-libinput 1.2.1-1+b1`, utilitário `xinput 1.6.3-1`.
- **KlipperScreen**: `v0.4.6-65-ga840560` (commit `a840560`, 2026-03-10).
