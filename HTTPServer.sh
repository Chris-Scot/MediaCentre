#!/bin/bash

export Base="$(dirname "$(readlink -f "$0")")"
export InstanceName="${0##*/}"
EnvFile="$Base/${InstanceName%.sh}.env"

################################################################################
#  Logging functions
################################################################################

function LogInfo { echo "$(date +%F\ %T)  INFO:  $*" >> $LogFile ; }
function LogWarning { echo "$(date +%F\ %T)  WARNING:  $*" >> $LogFile ; }
function LogError { echo "$(date +%F\ %T)  ERROR:  $*" >> $LogFile ; }

################################################################################
#  Environment and configuration
################################################################################

function LoadEnv {
   if [ ! -f "$EnvFile" ]; then
      CreateEnv
      . "$EnvFile"
      mkdir -p "$EPGDir" "$WebDir"
   else
      . "$EnvFile"
   fi

   LogInfo "Loaded environment from $EnvFile"
}

function CreateEnv {
   cat << EOF > "$EnvFile"
EPGDir="\$Base/EPG"
WebDir="\$Base/Web"
LogFile="\$WorkDir/${InstanceName%.sh}.log"
LogFile="/dev/stderr"
Port=8480
EOF
   LogInfo "Created environment template: $EnvFile"
}

################################################################################
#  Helper / Utility functions
################################################################################

function EncodeXML {
   local Result="${1//&/&amp;}"
   Result="${Result//</&lt;}"
   Result="${Result//>/&gt;}"
   Result="${Result//\"/&quot;}"
   Result="${Result//\'/&apos;}"
   echo "$Result"
}

################################################################################
#  Starting & Stopping
################################################################################

function Initialize {
   LoadEnv
   LogInfo "Initialization complete"
}

function Finalize {
   LogInfo "Finalizing script"
}

################################################################################
#  Main execution
################################################################################

Initialize

##############################################################################
# Server mode (no arguments)
##############################################################################

if [ "$1" = "" ]; then
   LogInfo "Starting HTTP server on port $Port using nc."
   LogInfo "Base directory: $Base"

   # Persistent listen, call THIS script with argument "Run"
   nc -ll 0.0.0.0 -p "$Port" -e "$0" Run

   LogInfo "nc exited, shutting down server"

##############################################################################
# Request handler mode
##############################################################################

elif [ "${1^^}" = "RUN" ]; then
   # Read first request line only
   read RequestLine || exit 0

   Method="$(echo "$RequestLine" | cut -d' ' -f1)"
   PathQuery="$(echo "$RequestLine" | cut -d' ' -f2)"
   RequestPath="$(echo "$PathQuery" | awk -F'?' '{print $1}')"
   QueryString="$(echo "$PathQuery" | awk -F'?' '{print $2}')"

LogInfo "$Method"
LogInfo "$PathQuery"
LogInfo "$RequestPath"
LogInfo "$QueryString"

   Content=""
   ContentType="text/plain"

############################################################################
# Determine response based on RequestPath
############################################################################

   if [ "$RequestPath" = "/" ] || [ "$RequestPath" = "/index.html" ]; then
      RequestPath="/EPGDisplay.sh"
   fi
   if [ "${RequestPath: -3}" = ".sh" ]; then
      File="$Base/${RequestPath##*/}"
   else
      File="$WebDir/${RequestPath##*/}"
   fi

   if [ -f "$File" ]; then
      if [ "${File: -3}" = ".sh" ]; then
         Content="$("$File" 2>$LogFile)"
         ContentType="text/html"
      else
         Content="$(cat "$File")"
         if [ "${File: -4}" = ".htm" -o "${File: -5}" = ".html" ]; then
            ContentType="text/html"
         elif [ "${File: -3}" = ".js" ]; then
            ContentType="application/javascript"
         elif [ "${File: -4}" = ".css" ]; then
            ContentType="text/css"
         elif [ "${File: -5}" = ".json" ]; then
            ContentType="application/json"
         else
            ContentType="application/octet-stream"
         fi
      fi

      echo -en "HTTP/1.1 200 OK\r\n"
      echo -en "Content-Type: $ContentType\r\n"
      echo -en "Content-Length: ${#Content}\r\n"
      echo -en "\r\n"
      echo "$Content"
   else
      echo -en "HTTP/1.1 403 Not Found\r\n"
      echo -en "Content-Type: text/htmlr\n"
      echo -en "Content-Length: 9\r\n"
      echo -en "\r\n"
      echo "Not Found"
   fi

   while read -t .1; do
      LogInfo "Buffer data content = '$REPLY'."
   done

##############################################################################
# Unknown mode
##############################################################################

else
   LogError "Unknown mode: $1"
   exit 1
fi
