#!/usr/bin/env bash

source 'mod/tg_api/check_repost.sh'
source 'mod/host/file_mtime.sh'

declare -A data_arr

keys=(
  'ufgd_news_url'
  'tg_bot_api'
  'bot_token'
  'channel_id'
)

# TODO: dynamic filename
#
# getting links/tokens
data=$(<login.txt)

declare -i j
j=0

# attributing each data to the right key
for i in $data; do
  key="${keys[${j}]}"
  data_arr["$key"]="$i"

  j=$((++j))
done

unset j

# make requests to ufgd news and parse this data,
# maintain four files to compare two of them in each requests
#
get_json() {
  # first argument is the url path ('noticias' or 'informes')
  local path_json="/tmp/${1}.json"

  local -i hash=1

  #TODO: file_mtime()
  # check if file exists and has been modified in the last 5min,
  # to avoid requisitions if the script has been executed and stopped

  # change 'xxx' to 'informes' or 'noticias'
  site="${data_arr[ufgd_news_url]}"
  site="${site//xxx/${1}}"

  local -i http_code

  # file_mtime (path: mod/host/file_mtime.sh)
  local -i mtime=$(file_mtime "$path_json")

  if ! test -e "$path_json" || (( mtime == 0 )); then
    # getting news json
    http_code=$(curl --write-out "%{http_code}" \
      -s "$site" \
      -o "$path_json")

  else
    parse_data "$path_json" "$1"
    return 0

  fi

  if ! test -e "${path_json/.json/}_old.json" && \
    (( http_code == 200 )); then
    hash=0

    # other file name need to be: ${path_json}_old.json
    cp "$path_json" "${path_json/.json/}_old.json"

    parse_data "$path_json" "$1"

    return 0

  else
    (( http_code != 200 )) && \
      error_log "$http_code" \
    return 1
  fi

  # code = 200 and ufgd_news.json exists
  if (( http_code == 200 )) && test -e "$path_json"; then
    local new_file_hash
    local old_file_hash

  #TODO: make checksum only in the last news
  new_file_hash=$(md5sum < "$path_json")
  old_file_hash=$(md5sum < "${path_json/.json/}_old.json")

  # compare if the site data changed
  # ${#md5sum_string} -eq 32
  test "${new_file_hash::32}" != "${old_file_hash::32}" && hash=0

  # other file name need to be: ufgd_news_old.json
  cp "$path_json" "${path_json/.json/}_old.json"

  # if have new news the bot send msg:
  (( hash == 0 )) && parse_data "$path_json" "$1"

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
	
	if test "$2" = 'informes'; then
		resp_sec=$(jq ".${parent}[0].setorResponsavel" "$path_json" | \
			url_encode)
	else
		resp_sec=$(jq ".${parent}[0].autor" "$path_json" | url_encode)
	fi

	# the path '/informes' gives the beginning
	# of a URL other than '/news'
	url=$(jq ".${parent}[0].url" "$path_json" | url_encode)

	if test "$parent" = 'Noticias'; then
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
	check_repost "$full_text_news" && \
		bot_tg 0
}

url_encode() {
	local new_data
	local url

	if test -p /dev/stdin; then
		# reading data from pipe
		read -r data

		# putting backslashes to escape symbol chars
		# and reducing space size.

		# TODO: when this regex is applied to the '-' char,
		#	we have a problem, in the tg channel the msg is '\-'
		#  and note '-'
		new_data=$(sed -r "{
			s/\xc2\xa0/ /g
			s/\xa0//g
			s/[[:blank:]]/+/g
			s/[[:punct:]]/\\\\\0/g
		}" <<< "$data")

		echo "$new_data"
	fi
}

bot_tg() {
  chat_id="${data_arr[channel_id]}"
  text="$full_text_news"

  # send message to the dev,
  # these conditions are linked
  # with the function: 'error_log'
  if (( "$1" == 1 )); then
    text='bug on bot'
  fi # or send default msg to channel

  # request bot_api with parsed text
  curl -s \
    -X POST \
    "${data_arr[tg_bot_api]}/bot${data_arr[bot_token]}/sendMessage" \
    -d chat_id="$chat_id" \
    -d parse_mode='MarkdownV2' \
    -d text="$text" \
    | jq -r
}

main() {
	while true; do
	
		for i in 'noticias' 'informes';
		do
			get_json "$i"
		done

		sleep 5m
	done
}

main "$@"
