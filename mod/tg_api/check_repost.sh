#!/bin/bash

check_repost() {
	if [[ ! -e 'log/posts.txt' ]]; then
		echo -e "\n${full_text_news}" >> log/posts.txt
		return 0

	else
		local lines
		lines=$(wc -l < log/posts.txt) 

		local hash
		hash=$(md5sum <<< "$full_text_news")
		hash=${hash::32}

		for (( i=0; i<="${lines}"; i++ ))
		do
			local old_posts
			old_posts=$(sed -n "$(( i + 1 ))p" 'log/posts.txt')
			hash_old=$(md5sum <<< "$old_posts")

			if [[ "${hash::32}" = "${hash_old::32}" ]]; then
				echo -e "[$(date +%H:%M)] this posts exists\n" \
					>> error_log

				return 1
			fi
		done
	fi

	return 0
}
