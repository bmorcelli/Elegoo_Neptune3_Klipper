#!/bin/bash
# Aplica a matriz de rotacao do touchscreen para casar com a rotacao do Xorg
# (ver Option "Rotate" em /etc/X11/xorg.conf.d/02-driver.conf).
#
# Chamado via ExecStartPost do KlipperScreen.service, antes de o Xorg e o
# dispositivo de touch estarem necessariamente prontos - por isso espera
# ativamente por ambos em vez de um "sleep" fixo.

DEVICE="ADS7846 Touchscreen"
MATRIX="0 -1 1 -1 0 1 0 0 1"
TIMEOUT=30

export DISPLAY=:0

waited=0
until xinput list "$DEVICE" >/dev/null 2>&1; do
    waited=$((waited + 1))
    if [ "$waited" -ge "$TIMEOUT" ]; then
        echo "touchscreen-fix: '$DEVICE' nao apareceu apos ${TIMEOUT}s, abortando" >&2
        exit 1
    fi
    sleep 1
done

xinput set-prop "$DEVICE" "Coordinate Transformation Matrix" $MATRIX
