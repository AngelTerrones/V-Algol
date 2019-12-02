#!/usr/bin/env bash

Color_Off='\033[0m'
BGreen='\033[1;32m'
BYellow='\033[1;33m'
BRed='\033[1;31m'

VENV=$ROOT/.venv

if [ -d "$VENV" ]; then
    echo -e ${BRed}"Deleting old virtualenv"${Color_Off}
    rm -rf $VENV
fi

echo -e ${BYellow}"Creating python virtual environment"${Color_Off}
python3 -m venv $VENV
echo -e ${BYellow}"Installing zephyr requirements"${Color_Off}
source $VENV/bin/activate
pip3 install -r $(pwd)/software/zephyr/scripts/requirements.txt
deactivate
echo -e ${BGreen}"Virtualenv setup: DONE"${Color_Off}
