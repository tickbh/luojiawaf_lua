#!/bin/bash
echo `date` "del luojia" $1 >> /luojia/logs/forbidden.log
ipset del luojia $1
