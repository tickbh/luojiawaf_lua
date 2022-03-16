#!/bin/bash
echo `date` "add luojia" $1 "timeout" $2 >> /luojia/logs/forbidden.log
ipset add luojia $1 timeout $2
