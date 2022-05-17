#!/bin/bash

# DNS API for Domain-Offensive / Resellerinterface / Domainrobot

# Report bugs at https://github.com/Neilpang/acme.sh/issues/TBC

# set these environment variables to match your customer ID and password:
# DO_PID="KD-1234567"
# DO_PW="cdfkjl3n2"

DO_URL="https://core.resellerinterface.de/"

########  Public functions #####################

#Usage: dns_myapi_add   _acme-challenge.www.domain.com   "XKrxpRBosdIKFzxW_CT3KLZNf6q0HG9i01zxXp5CPBs"
dns_dorest_add() {
  fulldomain=$1
  txtvalue=$2
  if _dns_do_authenticate; then
    _info "Adding TXT record to ${_domain} as ${fulldomain}"
    _dns_do_rest "dns/createRecord" domain "${_domain}" name "${fulldomain}" type TXT content "${txtvalue}" ttl 300
    if _contains "${response}" '"stateName":"OK"'; then
      return 0
    fi
    _err "Could not create resource record, check logs"
  fi
  return 1
}

#fulldomain
dns_dorest_rm() {
  fulldomain=$1
  if _dns_do_authenticate; then
    if _dns_do_list_rrs; then
      _dns_do_had_error=0
      for _rrid in ${_rr_list}; do
        _info "Deleting resource record $_rrid for $_domain"
        _dns_do_rest "dns/deleteRecord" domain "${_domain}" id "${_rrid}"
        if ! _contains "${response}" '"stateName":"OK"'; then
          _dns_do_had_error=1
          _err "Could not delete resource record for ${_domain}, id ${_rrid}"
        fi
      done
      return $_dns_do_had_error
    fi
  fi
  return 1
}

####################  Private functions below ##################################
_dns_do_authenticate() {
  _info "Authenticating as ${DO_PID}"
  
  #_dns_do_soap authPartner partner "${DO_PID}" password "${DO_PW}"
  _dns_do_rest "reseller/login" username "${DO_PID}" password "${DO_PW}"
  if _contains "${response}" '"stateName":"OK"'; then
    _get_root "$fulldomain"
    _debug "_domain $_domain"
    return 0
  else
    _err "Authentication failed, are DO_PID and DO_PW set correctly?"
  fi
  return 1
}

_dns_do_list_rrs() {
  _dns_do_rest "dns/getZoneDetails" domain "${_domain}"
  if ! _contains "${response}" '"stateName":"OK"'; then
    _err "dns/getZoneDetails domain ${_domain} failed"
    return 1
  fi
  rrname=$(echo "$fulldomain" | sed "s/\(.*\)\.${_domain}/\1/g")
  _debug2 "rrname=$rrname"
  _debug2 "response: ${response}"
  _rr_list="$(echo "${response}" |
    sed 's/,/\n/g' | 
    grep '"name":"'"${rrname}" -B1 | 
    grep id |
    sed 's/^.*id":\(.*$\)/\1/g')"

  _debug2 "RR List: ${_rr_list}"
  [ "${_rr_list}" ]
}

_dns_do_rest() {
  func="$1"
  shift
  # put the parameters to form data
  _body=""

  i=0
  while [ "$1" ]; do
    if [ $i == 0 ]; then
        delim=""
    else
        delim="&"
    fi
    _k="$1"
    shift
    _v="$1"
    shift
    _body="$_body$delim$_k=$_v"
    i=$(_math $i + 1)
  done

  _debug2 "REST request ${_body}"

  # set REST Form headers
  export _H1="Content-Type: application/x-www-form-urlencoded"

  if ! response="$(_post "${_body}" "${DO_URL}/${func}")"; then
    _err "Error <$1>"
    return 1
  fi
  _debug2 "JSON response $response"

  # retrieve cookie header
  if [ -z "$_H2" ]; then
      _H2="$(_egrep_o 'Cookie: [^;]+' <"$HTTP_HEADER" | _head_n 1)"
  fi

  _debug2 "_H2 Cookie: $_H2"
  export _H2

  return 0
}

_get_root() {
  domain=$1
  i=2
  found=false
  while ! $found; do
    h=$(printf "%s" "$domain" | rev | cut -d . -f 1-$i | rev)

    if [ $i -gt 3 ]; then
      break
    fi

    if [ -z "$h" ]; then
      return 1
    fi

    _dns_do_rest "dns/getZoneDetails" domain "$h"
    if _contains "${response}" '"stateName":"OK"'; then
      _domain="$h"
      return 0
    fi

    i=$(_math $i + 1)
  done

  _debug "$domain not found"
  return 1
}
