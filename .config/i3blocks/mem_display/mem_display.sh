#!/bin/bash
#
if  ! test -f /tmp/i3blocks-mem-display.state;  then
	echo 0 > /tmp/i3blocks-mem-display.state
fi

state="$(cat /tmp/i3blocks-mem-display.state)"

if [ -n "$BLOCK_BUTTON" ]
then
	if [ $state -eq 0 ]
	then
		echo 1 > /tmp/i3blocks-mem-display.state
		state=1
	else 
		echo 0 > /tmp/i3blocks-mem-display.state
		state=0
	fi
fi

if [ $state -eq 0 ]
then
	free -m | awk 'NR==2{printf "  %.1f%", $3 / $2 * 100}'
else 
	free -m | awk 'NR==3{printf "  %.1f%", $3 / $2 * 100}'
fi
