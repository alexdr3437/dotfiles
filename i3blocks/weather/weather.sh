#!/bin/bash
weather=($(curl --silent http://api.openweathermap.org/data/2.5/weather/\?id\=5969785\&units\=metric\&appid\=aa7a65d9aed0d5542e1c64fa1a23611d | jq -r '[(.main.feels_like|round), (.main.temp_max|round), (.weather[0].description)] | join(" ")'))
echo "${weather[@]:2} ${weather[0]}°C | ${weather[1]}°C"

