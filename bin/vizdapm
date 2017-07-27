#!/bin/bash
#
# Copyright 2011, 2012, 2013 Wolfson Microelectronics plc
# Author: Dimitris Papastamos <dp@opensource.wolfsonmicro.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License version 2 as
# published by the Free Software Foundation.
#
# A tool to generate a visual graph of the current DAPM configuration.
# Active paths are shown in green, inactive in red.
#
# This program requires `graphviz' to be installed.

if [ $# -ne 2 ]; then
	echo "Usage: $(basename $0) dapm-debugfs-path outfile[.png]" 1>&2
	echo "" 1>&2
	echo "  If the outfile ends with .png then a PNG file is created" 1>&2
	echo "  using dot executable, otherwise the outfile will contain" 1>&2
	echo "  the dot representation." 1>&2
	exit 1
fi

widgets="$1"
outfile="$2"
graphviztmp=$(mktemp)

trap "{ rm -f $graphviztmp; exit 1; }" SIGINT SIGTERM EXIT

widget_active() {
	local w="$1"
	head -1 "$w" | grep -q ': On'
	if [ "$?" -eq 0 ]; then
		echo 1
	else
		echo 0
	fi
}

echo "digraph G {" > "$graphviztmp"
echo -e "\tbgcolor = grey" >> "$graphviztmp"

cd "$widgets"
find . -type f | while read widget; do
	echo -n "Parsing widget $widget..."
	while read line; do
		echo "${line}" | grep -q '^in'
		if [ ! "$?" -eq 0 ]; then
			continue
		fi
		source=$(echo "$line" | awk -F\" '{print $4}')
		active=$(widget_active "$widget")
		sink=$(basename "$widget")
		if [ "$active" -eq 1 ]; then
			echo -e "\t\"$source\" [color = green]" >> "$graphviztmp"
			echo -e "\t\"$sink\" [color = green]" >> "$graphviztmp"
		else
			echo -e "\t\"$source\" [color = red]" >> "$graphviztmp"
			echo -e "\t\"$sink\" [color = red]" >> "$graphviztmp"
		fi
		echo -e "\t\"$source\" -> \"$sink\"" >> "$graphviztmp"
	done < "$widget"
	echo "OK!"
done
cd - >/dev/null

echo "}" >> "$graphviztmp"

echo ""
if [ "${outfile##*.}" = "png" ]; then
    echo -n "Generating $outfile..."
    dot -Kfdp -Tpng "$graphviztmp" -o "$outfile"
    echo "OK!"
else
    mv "$graphviztmp" "$outfile"
    chmod a=rw "$outfile"

    echo "Generate PNG with:"
    echo "dot -Kfdp -Tpng $outfile -o $outfile.png"
fi
