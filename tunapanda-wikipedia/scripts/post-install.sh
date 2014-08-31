#!/bin/bash

if grep '\<wikipedia\>' /etc/hosts &> /dev/null
then
	echo "127.0.0.1	wikipedia www.wikipedia.org en.wikipedia.org wikipedia.org" >> /etc/hosts
fi
