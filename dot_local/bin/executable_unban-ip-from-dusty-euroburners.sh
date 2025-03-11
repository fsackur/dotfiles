#! /usr/bin/bash

my_ip=$(curl -fs4 https://myip.dk)
ssh dusty -C sudo fail2ban-client unban $my_ip
