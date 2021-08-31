#!/bin/bash

declare -a data_arr
#the array begins in 1, not 0
#1: ufgd_news_url; #2: tg_bot_api; 3: bot_token; 4: chat_id; 5: dev_chat_id
for i in {1..5}
do
	data_arr[${i}]=$(sed -n "${i}p" "$1")
done

# make requests to ufgd news and parse this data,
# maintain two files to compare in each requests
get_json() {
	path_json='/tmp/ufgd_news.json'

	#testing if file exists
	hash=0
	if [[ -e $path_json ]]; then
		cp  $path_json "${path_json/.json/}_news.json"

		curl -L -s "${data_arr[1]}" -o $path_json
		
		new_file_hash=$(md5sum < $path_json)

		#TODO: correct this replacement
		old_file_hash=$(md5sum < "${path_json/.json/}_news.json")

		#compare if the site changed
		hash=1
		if [[ ${new_file_hash::32} != "${old_file_hash::32}" ]]; then
			hash=0
		fi

		[[ $hash -eq 0 ]] && parse_data $hash

	else
		curl -L -s "${data_arr[1]}" -o $path_json
		parse_data $hash

	fi
}

	
parse_data() {
	if [[ $1 -eq 0 ]]; then

		title=$(jq '.Informes[0].titulo' "$path_json" | \
			sed 's/\./\\./g; s/\"//g; s/  / /g; s/ /\+/g; s/\-/\\-/g')

		desc=$(jq '.Informes[0].descricao' "$path_json" | \
			sed 's/\./\\./g; s/\"//g; s/  / /g; s/ /\+/g; s/\-/\\-/g')

		resp_sec=$(jq '.Informes[0].setorResponsavel' "$path_json" | \
			sed 's/\./\\./g; s/\"//g; s/  / /g; s/ /\+/g; s/\-/\\-/g')
										
		url=$(jq '.Informes[0].url' "$path_json" | \
			sed 's/\./\\./g; s/\"//g; s/  / /g; s/ /\+/g; s/\-/\\-/g')

		#formating to post in telegram

		title="*${title}*+"
		resp_sec="%0A__Fonte:+${resp_sec}__%0A%0A"
		desc="${desc}%0A"
		ufgd_url="https://ufgd.edu.br"
		url="\[[acesse\_aqui](${ufgd_url}${url})\]"
	
		full_text_news="${title}${resp_sec}${desc}${url}"

		bot_tg "$1"

	else
		echo "[$(date +%H%M)] error: $1" >> error_log
		bot_tg "$1"

	fi
}

bot_tg() {
	chat_id=${data_arr[4]}
	text=${full_text_news}

	# send message to de dev
	if [[ $1 -eq 1 ]]; then
		chat_id=${data_arr[5]}
		text="bug+on+bot"
	fi

	curl -L -s \
	-X POST \
	"${data_arr[2]}/bot${data_arr[3]}/sendMessage" \
	-d chat_id="$chat_id" \
	-d parse_mode='MarkdownV2' \
	-d text="$text"
}

main() {
	while true; do
		get_json
		sleep 300 
	done
}

main "$@"
