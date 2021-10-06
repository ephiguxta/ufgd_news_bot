#!/bin/bash

source 'mod/tg_api/check_repost.sh'

declare -a data_arr
# 1: ufgd_news_url
# 2: tg_bot_api
# 3: bot_token
# 4: chat_id
# 5: dev_chat_id

for i in {1..5}
do
	# good vectors start at zero
	data_arr[$(( i - 1 ))]=$(sed -n "${i}p" "$1")
done

# make requests to ufgd news and parse this data,
# maintain four files to compare two of them in each requests
get_json() {
	local path_json="/tmp/${1}.json"
	hash=1

	#TODO: file_mtime()
	#	check if file exists and has been modified in the last 5min,
	#	to avoid requisitions if the script has been executed and stopped

	# trade 'xxx' to 'informes' or 'noticias'
	site="${data_arr[0]}"
	site="${site//xxx/${1}}"

	# getting news json
	http_code=$(curl --write-out "%{http_code}" \
								-s "$site" \
								-o "$path_json")

	if [[ ! -e "${path_json/.json/}_old.json" && \
		$http_code -eq 200 ]]; then
			hash=0

			# other file name need to be: ${path_json}_old.json
			cp "$path_json" "${path_json/.json/}_old.json"

			parse_data "$path_json" "$1"

			# TODO: make a functional return 
			return
	else

		[[ $http_code -ne 200 ]] && \
			error_log "$http_code" \
			return # see the last TODO
	fi
			
	# code = 200 and ufgd_news.json is valid
	if [[ $http_code -eq 200 && -e $path_json ]]; then
		local new_file_hash
		local old_file_hash

		#TODO: make checksum only in the last news
		new_file_hash=$(md5sum < "$path_json")
		old_file_hash=$(md5sum < "${path_json/.json/}_old.json")

		# compare if the site data changed
		# ${#md5sum_string} -eq 32
		[[ "${new_file_hash::32}" != "${old_file_hash::32}" ]] && hash=0

		# other file name need to be: ufgd_news_old.json
		cp "$path_json" "${path_json/.json/}_old.json"

		# if have new news the bot send msg:
		[[ $hash -eq 0 ]] && parse_data "$path_json" "$1"
		
	else
		# if request not valid and file json not generated,
		# generate logs and msg to dev
		error_log "$http_code"

	fi
}

# if the reqs to the site fail, the dev will
# ne notified
error_log() {
	echo "[$(date +%H:%M)] http_code: $http_code" >> error_log
	bot_tg 1
}
	
parse_data() {
	# treating brute data from json and passing
	# to url_encode treat them

	parent="${2^}"
	
	title=$(jq ".${parent}[0].titulo" "$path_json" | url_encode)

	desc=$(jq ".${parent}[0].descricao" "$path_json" | url_encode)
	
	if [[ "$2" == 'informes' ]]; then
		resp_sec=$(jq ".${parent}[0].setorResponsavel" "$path_json" | url_encode)
	else
		resp_sec=$(jq ".${parent}[0].autor" "$path_json" | url_encode)
	fi

	# the path '/informes' gives the beginning
	# of a URL other than '/news'
	url=$(jq ".${parent}[0].url" "$path_json" | url_encode)
	if [[ "${parent}" == 'Noticias' ]]; then
		to_del="${url:0:2}"
		
		# inserting some '/' to validate the url
		url="\/\/noticias/${url/${to_del}/}"
	fi
	
	# formating to post in telegram

	title="*${title}*%0A"
	resp_sec="%5F%5FFonte:%20${resp_sec}%5F%5F%0A%0A"
	desc="${desc}%0A"

	ufgd_url='https://ufgd\.edu\.br'
	url="\[[acesse\_aqui](${ufgd_url}${url:3:-2})\]"

	full_text_news="${title}${resp_sec}${desc}${url}"

	# if the post exists on the channel, don't post him
	check_repost "${full_text_news}" && \
		bot_tg 0
}

url_encode() {
	local new_data
	local url

	if [[ -p /dev/stdin ]]; then
		# reading data from pipe
		read -r data

		# putting backslashes to escape symbol chars
		# and reducing space size.
		new_data=$(sed -r "{
			s/\xc2\xa0{2}//g
			s/\xc2\xa0/ /g
			s/[[:blank:]]/+/g
			s/[[:punct:]]/\\\\\0/g
		}" <<< "$data")

		#TODO: another way to redirect?!
		echo "$new_data"
	fi
}

bot_tg() {
	chat_id="${data_arr[3]}"
	text="$full_text_news"

	# send message to the dev,
	# these conditions are linked
	# with the function: 'error_log' 
	if [[ "$1" -eq 1 ]]; then
		chat_id="${data_arr[4]}"
		text="bug on bot"

	fi # or send default msg to channel

	# request bot_api with parsed text
	curl -s \
	-X POST \
	"${data_arr[1]}/bot${data_arr[2]}/sendMessage" \
	-d chat_id="$chat_id" \
	-d parse_mode='MarkdownV2' \
	-d text="$text"
}

main() {
	while true; do
	
		for i in "noticias" "informes";
		do
			get_json "$i"
		done

		sleep 5m
	done
}

main "$@"
