#!/bin/bash

git clone https://github.com/miiton/Cica.git /tmp/Cica
cd /tmp/Cica
docker-compose build ; docker-compose run --rm cica

cp -f /tmp/Cica/dist/Cica-*.ttf ~/Library/Fonts/

