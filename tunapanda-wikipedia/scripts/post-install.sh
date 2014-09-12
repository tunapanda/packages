#!/bin/bash

for m in mod_rewrite mod_speling
do
    ln -sf /etc/apache2/mods-available/$m /etc/apache2/mods-enabled/$m
done
