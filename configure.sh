#!/bin/bash

declare -a data

# basic data
data[0]='https://ufgd.edu.br/xxx/listagem?pagina=1'
data[1]='https://api.telegram.org'

input_prompt() {
	questions=("bot_token" "channel_id" "dev_id")
	
	# +2 = data[{0, 1}]
	for ((i = 0; i < $(( ${#questions[@]} + 2 )); i++));
	do
		if [[ $i -gt 1 ]]; then 
			# 0..4
			echo -n "${questions[$(( i - 2 ))]}: "
			read input
			data[${i}]=$input
		fi
		
		echo ${data[${i}]} >> data.txt
	done
}

main() {
	input_prompt

	# creating repo to store logs
	# TODO: just this?!
	mkdir log
}

main
