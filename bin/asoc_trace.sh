#!/bin/sh
#
# Copyright 2011 Wolfson Microelectronics plc
# Author: Dimitris Papastamos <dp@opensource.wolfsonmicro.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License version 2 as
# published by the Free Software Foundation.
#
# A simple tool to enable verbose debugging of ASoC's tracepoint hooks.
#
# First generate the register map for the CODEC you are going to debug
# as shown below:
# ./asoc_trace.sh -i wm8994_regs.h -r regmap -g
#
# The wm8994_regs.h file should _only_ contain the CODEC's registers
# in the form:
# #define <REG_NAME> <REG_IDX>
#
# After you've enabled ASoC's snd_soc_read/snd_soc_write tracepoints
# you can do the following to beautify the output.
# ./asoc_trace.sh -r regmap -c wm8994
#
# This will look for the trace file under /sys/kernel/debug/tracing/trace.
# If you want to provide your own trace use the '-t' option.
#

usage()
{
cat << EOF
usage: $0 options
	-h show this help message
	-i input header file
	-t input trace file
	-g generate the register map file
	-r register map file
	-c codec name
EOF
}

# return the register name given the register index
register_name()
{
	local regheader=$1
	local regindex=`echo $(($regindex))`

	matches=`grep -i " "$regindex"$" $regheader`
	if [ "$?" -eq 0 ]; then
		local idx=`echo "${matches}" | awk '{print $2}'`
		idx=`echo $(($idx))`
		if [ "$idx" = "$regindex" ]; then
			local regname=`echo "${matches}" | awk '{print $1}'`
			echo $regname;
			return
		fi
	fi
}

# generate a register map to be used for mapping register indices to
# register names
generate_regmap()
{
	[ -f "$2" ] && rm -f $2
	while read line; do
		local idx=`echo "${line}" | awk '{print $3}'`
		idx=`echo $(($idx))`
		local regname=`echo "${line}" | awk '{print $2}'`
		echo "$regname $idx" >> $2
	done < "$1"
}

codec_name=
input_header=
input_trace=
regmap=
genmap=
tmpfile=`mktemp`

trap "{ [ -f "$tmpfile" ] && rm -f $tmpfile; exit; }" EXIT SIGINT SIGTERM

while getopts "hc:i:t:r:g" option
do
	case $option in
	h)
		usage
		exit 1
		;;
	c)
		codec_name=$OPTARG
		;;
	i)
		input_header=$OPTARG
		;;
	t)
		input_trace=$OPTARG
		;;
	r)
		regmap=$OPTARG
		;;
	g)
		genmap=1
		;;
	?)
		usage
		exit 1
		;;
	esac
done

if [ "$genmap" = "1" ]; then
	if [[ -z "$regmap" ]]; then
		echo "Please provide the register map file" 1>&2
		usage
		exit 1
	else
		if [[ -z "$input_header" ]]; then
			echo "Please provide the input header file" 1>&2
			usage
			exit 1
		fi
		generate_regmap $input_header $regmap
		exit
	fi
fi

if [[ -z "$codec_name" ]]; then
	echo "Please provide the codec name" 1>&2
	usage
	exit 1
fi

if [[ -z "$regmap" ]]; then
	if [[ -z "$input_header" ]]; then
		echo "Please provide the input header" \
			"or the register map file" 1>&2
		usage
		exit 1
	fi
	generate_regmap $input_header $tmpfile
	regmap=$tmpfile
fi

if [[ -z "$input_trace" ]]; then
	mount | grep -q -i debugfs
	# XXX: make this more flexible?
	if [ ! "$?" -eq 0 ]; then
		input_trace="/dev/stdin"
	else
		input_trace="/sys/kernel/debug/tracing/trace"
	fi
fi

while read line; do
	pattern="codec="$codec_name
	# just match our own codec, ignore any others
	echo "${line}" | grep -q -i "$pattern"
	if [ ! "$?" -eq 0 ]; then
		echo "${line}"
		continue
	fi
	# only match write/read hooks
	if echo "${line}" | grep -q "snd_soc_reg_write:" ||
		echo "${line}" | grep -q "snd_soc_reg_read:"; then
		# grab the register index field in decimal
		regindex=`echo "${line}" | awk '{print $6}' \
			| sed 's/reg=//'`
		regindex=`echo $((0x$regindex))`
		# grab the register name of this register
		regname=`register_name $regmap $regindex`
		if [ "$regname" = "" ]; then
			regname="unknown"
		fi
		# dump the output
		echo "${line}" | awk '{print $1"\t"$2"\t"$3"\t"$4"\t"$5"\t" \
			$6"\t"$7"\t\t""reg_name="v1}' v1=$regname
	else
		echo "${line}"
	fi
done < "$input_trace"
