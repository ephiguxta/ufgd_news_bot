#!/usr/bin/env bash

file_mtime() {
	local last_change
	local new_change
	
	# greping last modfied hour and minute from old json file
	last_change=$(stat --format='%y' -t "$1" | \
		grep -Eo '[0-9]{2}:[0-9]{2}')
	# greping actual time
	new_change=$(date '+%H:%M')


	local last_hour
	local last_min

	# parsing data into hour and minute
	last_hour="${last_change::2}"
	last_min="${last_change:3:2}"
	# deleting "0[0-9]+" cases
	last_min="${last_min##0}"

	local new_hour
	local new_min
	
	new_hour="${new_change::2}"
	new_min="${new_change:3:2}"
	new_min="${new_min##0}"

	local math_check
	math_check="$(( last_min - new_min ))"
	if [ $last_hour -lt $new_hour ] || [ $math_check -le -5 ]; then
		return 0
	fi

	return 1
}
