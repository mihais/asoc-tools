#!/bin/sh
#
# Copyright 2011 Wolfson Microelectronics plc
# Author: Dimitris Papastamos <dp@opensource.wolfsonmicro.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License version 2 as
# published by the Free Software Foundation.
#
# A tool to generate a visual graph of the current DAPM configuration.
# Active paths are shown in green, inactive in red.
#
# This program requires `dot' to be installed.
#

usage()
{
cat << EOF
usage: $0 <dapm-debugfs-directory> <graph-dot-file> <graph-jpg-file>
EOF
exit 1
}

if [ "$#" -ne 3 ]; then
    usage
fi

active=
curpath=`pwd`
dapm_debugfs="$1"
graph_file=${curpath}"/$2"
graph_file_jpg=${curpath}"/$3"

trap "{ [ -f "$graph_file" ] && rm -f "$graph_file"; exit; }" SIGINT SIGTERM

echo "digraph G {" > "$graph_file"
echo -e "\tbgcolor = grey" >> "$graph_file"

pushd "$dapm_debugfs" >/dev/null
for i in *; do
    active=0
    head -1 "$i" | grep -q ': On'
    if [ "$?" -eq 0 ]; then
	active=1
    fi
    while read line; do
	echo "${line}" | grep -q '^in'
	if [ ! "$?" -eq 0 ]; then
	    continue
	fi
	source=`echo "${line}" | awk -F\" '{print $4}'`
	if [ "$active" -eq 1 ]; then
	    echo -e "\t\"$source\" [color = blue]" >> "$graph_file"
	    echo -e "\t\"$i\" [color = blue]" >> "$graph_file"
	else
	    echo -e "\t\"$source\" [color = red]" >> "$graph_file"
	    echo -e "\t\"$i\" [color = red]" >> "$graph_file"
	fi
	echo -e "\t\"$source\" -> \"$i\"" >> "$graph_file"
    done < "$i"
done
popd >/dev/null

echo "}" >> "$graph_file"
dot -Kfdp -Tjpg "$graph_file" -o "$graph_file_jpg"
