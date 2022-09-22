#!/usr/bin/env bash

file_mtime() {
	local last_change
	local new_change

	# this check is necessary to avoid errors on the first
	# script attempt
	if ! test -e "$1"; then
		return 0
	fi

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
        last_hour="${last_hour##0}"
	last_min="${last_min##0}"

        echo "last_{hour,minute} : [${last_hour}:${last_min}]" >> debug

	local new_hour
	local new_min
	
	new_hour="${new_change::2}"
	new_min="${new_change:3:2}"

        new_hour="${new_hour##0}"
	new_min="${new_min##0}"

	local -i math_check
	math_check="$(( last_min - new_min ))"

        # TODO: a bug in logic, what happens if the script
        # is stopped and run another day?
	if (( last_hour < new_hour )) || (( math_check <= -5 )); then
		return 0
	fi

	return 1
}
