#!/bin/bash

if grep '\<ka-lite\>' /etc/hosts &> /dev/null
then
	echo "127.0.0.1	ka-lite" >> /etc/hosts
fi
