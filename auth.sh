#!/bin/bash 

if [ $1 = "username" ] && [ $2 = "password" ]
then
    exit 0
else
    exit 1
fi
