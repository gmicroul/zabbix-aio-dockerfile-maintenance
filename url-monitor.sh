#!/bin/bash
## Zabbix Agent URL Monitoring with automatic discovery and check script for X509/SSL/HTTPS certificates
## author: Ugo Viti <ugo.viti@initzero.it>
version=20230802

## example of Zabbix WEB SSL Monitor JSON input file generated by LLD discovery
# {
#   "data":
#   [
#    { "{#URL}":"https://www.initzero.it", "{#SCHEMA}":"https", "{#HOST}":"www.initzero.it", "{#PORT}":"443", "{#ITEMNAME}":"www.initzero.it:443" },
#    { "{#URL}":"https://www.wearequantico.it", "{#SCHEMA}":"https", "{#HOST}":"www.wearequantico.it", "{#PORT}":"443", "{#ITEMNAME}":"www.wearequantico.it:443" },
#    { "{#URL}":"https://www.example.com:10443", "{#SCHEMA}":"https", "{#HOST}":"www.example.com", "{#PORT}":"10443", "{#ITEMNAME}":"www.example.com:10443" }
#   ]
# }


# define custom curl User-Agent header
curlUserAgent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/103.0.5060.114 Safari/537.36 Edg/103.0.1264.49"
# curlUserAgent="Mozilla/5.0 (compatible; Zabbix-URL-Monitor/$version;)"

# tmp directory of cookies files
curlCookiesDir="/tmp/zabbix-url-monitor"

# timeout expire for cookies file (in seconds)
curlCookiesCacheTime="3600"

# curl connect timeout
curlConnectTimeOut=5

# curl overall download max time
curlMaxTime=20


cmd="$1"
shift
args="$@"

if [ -z "$cmd" ];then
  echo "ERROR: missing command... exiting"
  echo
  echo "USAGE:"
  echo "$0 url.discovery /etc/zabbix/url-monitor.csv"
  echo "$0 url.discovery http://someserver/url-monitor.csv"
  echo "$0 url.monitor https://www.example.com"
  exit 1
elif [ -z "$args" ];then
  echo "ERROR: missing args... exiting"
  exit 1
fi


#
# URI parsing function
#
# The function creates global variables with the parsed results.
# It returns 0 if parsing was successful or non-zero otherwise.
#
# [schema://][user[:password]@]host[:port][/path][?[arg1=val1]...][#fragment]
#
# thanks to: https://wp.vpalos.com/537/uri-parsing-using-bash-built-in-features/
function uri_parser() {
    # uri capture
    uri="$@"

    # safe escaping
    uri="${uri//\`/%60}"
    uri="${uri//\"/%22}"

    # top level parsing
    pattern='^(([a-z]{3,5}):\/\/)?((([^:\/]+)(:([^@\/]*))?@)?([^:\/?]+)(:([0-9]+))?)(\/[^?]*)?(\?[^#]*)?(#.*)?$'
    [[ "$uri" =~ $pattern ]] || return 1;

    # component extraction
    uri=${BASH_REMATCH[0]}
    uri_schema=${BASH_REMATCH[2]}
    uri_address=${BASH_REMATCH[3]}
    uri_username=${BASH_REMATCH[5]}
    uri_password=${BASH_REMATCH[7]}
    uri_host=${BASH_REMATCH[8]}
    uri_port=${BASH_REMATCH[10]}
    uri_path=${BASH_REMATCH[11]}
    uri_query=${BASH_REMATCH[12]}
    uri_fragment=${BASH_REMATCH[13]}

    # path parsing
    count=0
    path="$uri_path"
    pattern='^/+([^/]+)'
    while [[ $path =~ $pattern ]]; do
        eval "uri_parts[$count]=\"${BASH_REMATCH[1]}\""
        path="${path:${#BASH_REMATCH[0]}}"
        let count++
    done

    # query parsing
    count=0
    query="$uri_query"
    pattern='^[?&]+([^= ]+)(=([^&]*))?'
    while [[ $query =~ $pattern ]]; do
        eval "uri_args[$count]=\"${BASH_REMATCH[1]}\""
        eval "uri_arg_${BASH_REMATCH[1]}=\"${BASH_REMATCH[3]}\""
        query="${query:${#BASH_REMATCH[0]}}"
        let count++
    done

    # return success
    return 0
}

# print CSV formatted list removing blank and commented lines
parseCSV() {
  csv="$1"
  uri_parser "$1"

  if [ -z "$uri_schema" ]; then
      cat "$csv" | dos2unix | sed -e '/^#/d' -e '/^$/d' -e '/^{#/d'
    else
      curl -s "$csv" | dos2unix | sed -e '/^#/d' -e '/^$/d' -e '/^{#/d'
  fi
}

detectURLParts() {
  uri_parser "$1"

  # default to https
  if [ -z "$uri_schema" ]; then
      uri_schema="https"
  fi

  if [ -z "$uri_port" ]; then
    case $uri_schema in
      http) uri_port="80" ;;
      *)    uri_port="443" ;;
    esac
  fi

  URL="$1"
  SCHEMA="$uri_schema"
  HOST="$uri_host"
  PORT="$uri_port"
  RPATH="${uri_path}${uri_query}${uri_fragment}"
}

printURLs() {
  parseCSV "$1" | while read URL; do
    detectURLParts "$URL"
    if   [[ "${SCHEMA}" = "http" && "${PORT}" = "80" ]]; then
        unset URL_PORT
    elif [[ "${SCHEMA}" = "https" && "${PORT}" = "443" ]]; then
        unset URL_PORT
      else
        URL_PORT=":${PORT}"
    fi

    # set ITEMNAME
    # always use the port in the Item Name
    #ITEMNAME="${HOST}:${PORT}"

    # only use the port in the Item Name if not used port 443
    #[[ "${PORT}" != "443" ]] && ITEMNAME="${HOST}:${PORT}" || ITEMNAME="${HOST}"

    # only use the port in the Item Name if not port 80 and 443
    #[[ "${PORT}" != "80" || "${PORT}" != "443" ]] && ITEMNAME="${HOST}:${PORT}" || ITEMNAME="${HOST}"

    # only use the port in the Item Name if not port 80 and 443 and place the SCHEMA in the Item Name
    [[ "${PORT}" != "80" && "${PORT}" != "443" ]] && ITEMNAME="${SCHEMA}://${HOST}:${PORT}" || ITEMNAME="${SCHEMA}://${HOST}"

    echo "    { \"{#URL}\":\"${SCHEMA}://${HOST}${URL_PORT}${RPATH}\", \"{#SCHEMA}\":\"${SCHEMA}\", \"{#HOST}\":\"${HOST}\", \"{#PORT}\":\"${PORT}\", \"{#ITEMNAME}\":\"${ITEMNAME}\" },"
  done
}

## discovery rules
url.discovery() {
  echo "{
\"data\":
  ["
  printURLs "$1" | sed 'H;1h;$!d;x;s/\(.*\),/\1/'
  echo " ]
}"
}


# output in datetime format
getSSLExpireDate() {
  [ -z "$HOST" ] && echo "getSSLExpireDate: SSL host address not specified... exiting" && exit 1
  [ -z "$PORT" ] && echo "getSSLExpireDate: SSL port number not specified... exiting" && exit 1
  timeout $curlConnectTimeOut openssl s_client -host "$HOST" -port $PORT -servername "$HOST" -showcerts </dev/null 2>/dev/null | sed -n '/BEGIN CERTIFICATE/,/END CERT/p' | openssl x509 -text 2>/dev/null | sed -n 's/ *Not After : *//p'
}

# output in unixtime format
ssl.time_left() {
  if [ ! -z "$sslExpireDate" ]; then
    echo $(($(date '+%s' --date "$sslExpireDate") - $(date '+%s')))
   else
    return 1
  fi
}

# output in unixtime format
ssl.time_expire() {
  if [ ! -z "$sslExpireDate" ]; then
    date '+%s' --date "$sslExpireDate"
   else
    return 1
  fi
}

# check http/https server response code
getHTTPData() {
  # define cookies file name
  curlCookiesFile="${curlCookiesDir}/$(echo $HOST:$PORT/$RPATH | sed -e 's/[^A-Za-z0-9_-]/_/g').cookies"

  # use cookies file if exist otherwise create it
  if   [[ ! -e "$curlCookiesFile" ]]; then
    # create cookies dir if not exist
    [ ! -e "$curlCookiesDir" ] && install -m 750 -d "$curlCookiesDir"
    curlArgs+=" -c $curlCookiesFile"
  elif [[ "$(( $(date +"%s") - $(stat -c "%Y" $curlCookiesFile) ))" -gt "$curlCookiesCacheTime" ]]; then
    rm -f "$curlCookiesFile"
    curlArgs+=" -c $curlCookiesFile"
   else
    curlArgs+=" -b $curlCookiesFile"
  fi

  [ ! -z "$curlMaxTime" ]        && curlArgs+=" --max-time $curlMaxTime"
  [ ! -z "$curlConnectTimeOut" ] && curlArgs+=" --connect-timeout $curlConnectTimeOut"

  # FIXME: this doesn't works:
  #[ ! -z "$curlUserAgent" ]      && curlArgs+=" -H 'User-Agent: $curlUserAgent'"

  curlResponse="$(curl --tls-max 1.3 -L -s -w "%{http_code};%{time_total}" -H "User-Agent: $curlUserAgent" $curlArgs "$URL" -o /dev/null)"
  curlRetVal=$?

  # parse curl
  curlData=($(echo "$curlResponse" | sed 's/;/\n/g' | sed 's/,/./g'))

  ## manage when curl fail and not generate a valid HTTP error code
  # NOTE: this is a workaround, using cloudflare defined HTTP error codes (ref. https://en.wikipedia.org/wiki/List_of_HTTP_status_codes)

  ## use curl return code as http response code
  # curl: (6) Could not resolve host
  # curl: (7) Failed to connect
  # curl: (28) Connection timed out
  # curl: (60) SSL certificate problem: self signed certificate
  [[ "$curlRetVal" != "0" ]] && curlData[0]="$curlRetVal"

  # get ssl expire date if it's an https url and the web server is reachable
  if   [[ "$SCHEMA" = "https" ]] && [[ "$curlRetVal" = "0" || "$curlRetVal" = "60" ]];then
    getSSLData
  fi

  # if the certified is expired and the curl return code is 60 change $curlRetVal to 200
  [[ "$curlRetVal" = "60" && "$ssl_time_left" -lt "0" ]] && curlData[0]="200"

  # failback and map generic error to http code 1
  [[ "${curlData[0]}" = "000" && "$curlRetVal" = "0" ]] && curlData[0]="1"

  [ ! -z "${curlData[0]}" ] && http_code="${curlData[0]}"
  [ ! -z "${curlData[1]}" ] && time_total="${curlData[1]}"
}

# check ssl certificate expiration
getSSLData() {
  sslExpireDate=$(getSSLExpireDate)
  ssl_time_expire="$(ssl.time_expire)"
  ssl_time_left="$(ssl.time_left)"
}


# monitor the given URL
url.monitor() {
  detectURLParts "$1"

  # get HTTP request only for http and https protocols
  if [[ "$SCHEMA" = "http" || "$SCHEMA" = "https" ]];then
    getHTTPData
  elif [[ "$SCHEMA" = "tcp" ]];then
    # always save http code 200 if checking SSL certificate only
    data+="\"http_code\": 200, "
    data+="\"time_total\": 0, "
    getSSLData
  fi

  # when no ssl certificate get detected, save ssl_time_expire and ssl_time_left to default 0 (never)
  #[ -z "$ssl_time_expire" ] && data+="\"ssl_time_expire\": 0, "
  #[ -z "$ssl_time_left" ] && data+="\"ssl_time_left\": 0, "

  # compose the data var
  #data+="\"http_schema\":\"${SCHEMA}\", "
  [ ! -z "$http_code" ]       && data+="\"http_code\": $http_code, "
  [ ! -z "$time_total" ]      && data+="\"time_total\": $time_total, "
  [ ! -z "$ssl_time_expire" ] && data+="\"ssl_time_expire\": $ssl_time_expire, "
  [ ! -z "$ssl_time_left" ]   && data+="\"ssl_time_left\": $ssl_time_left, "

  # print json for zabbix
  echo "{ \"data\": [{ $(echo $data | sed 'H;1h;$!d;x;s/\(.*\),/\1/') }] }"
}

# execute the given command
#set -x
$cmd $args
exit $?
