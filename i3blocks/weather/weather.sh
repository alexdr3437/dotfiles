#!/bin/bash
weather=($(curl --silent http://api.openweathermap.org/data/2.5/weather/\?id\=5969785\&units\=metric\&appid\=aa7a65d9aed0d5542e1c64fa1a23611d | jq -r '[(.weather[].main|ascii_downcase), (.main.feels_like|round), (.main.temp_max|round)] | join(" ")'))
echo "${weather[0]} ${weather[1]}°C | ${weather[2]}°C"

