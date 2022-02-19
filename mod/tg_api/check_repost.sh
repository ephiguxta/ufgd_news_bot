#!/bin/bash

#TODO: maintain two logs instead just one
check_repost() {
	local full_text_news
	full_text_news="$1"

	# first time script being executed
	if ! test -d 'log'; then
		# putting data on posts.txt 
		mkdir log
		echo "$full_text_news" > log/posts.txt

		# first script start
		return 0

	else
		local lines
		# getting total of lines in posts.txt
		lines=$(wc -l < log/posts.txt) 

		local hash
		hash=$(md5sum <<< "$full_text_news")
		hash=${hash::32}

		for (( i=1; i<="$lines"; i++ ))
		do
			local old_posts
			old_posts=$(sed "${i}q;d" 'log/posts.txt')

			hash_old=$(md5sum <<< "$old_posts")
			hash_old="${hash_old::32}"

			if test "$hash" = "$hash_old"; then
				# posts exists on logs
				echo "[$(date +%H:%M)] this posts exists" >> error_log
				return 1

			else
				if test "$i" = "$lines"; then
					echo "$full_text_news" >> log/posts.txt
					return 0
				fi

				# compare the next post
				continue
			fi
		done
	fi

	return 0
}
