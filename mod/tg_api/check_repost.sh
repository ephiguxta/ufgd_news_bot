#!/bin/bash

#TODO: maintain two logs instead just one
check_repost() {
	local full_text_news
	full_text_news="$1"

	# first time script being executed
	if [[ ! -e 'log/posts.txt' ]]; then
		# putting data on posts.txt 
		mkdir log
		echo -e "\n$full_text_news" > log/posts.txt

	else
		local lines
		# getting total of lines in posts.txt
		lines=$(wc -l < log/posts.txt) 

		local hash
		hash=$(md5sum <<< "$full_text_news")
		hash=${hash::32}

		for (( i=0; i<="${lines}"; i++ ))
		do
			local old_posts
			# math expr is to avoid blank lines
			old_posts=$(sed "$(( i + 1 ))q;d" 'log/posts.txt')

			hash_old=$(md5sum <<< "$old_posts")
			hash_old="${hash_old::32}"

			if [[ "$hash" = "$hash_old" ]]; then
				# posts exists on logs
				echo -e "[$(date +%H:%M)] this posts exists\n" \
					>> error_log
				return 1

			else
				echo -e "\n$full_text_news" >> log/posts.txt
				return 0

			fi
		done
	fi

	return 0
}
