#!/bin/bash

certHome="/etc/haproxy/certs"

# Beolvassuk az összes *.pem fájlt a megadott mappából.
pem_files=$(ls $certHome/*.pem 2>/dev/null)

# Ha nincs *.pem fájl a mappában, akkor kiírjuk az üzenetet, majd kilépünk.
if [[ -z $pem_files ]]; then
  echo "Nincs *.pem fájl a megadott mappában."
  exit 1
fi

last_file=$(echo "$pem_files" | awk 'END {print}')

declare -A cert_info

function extract_cert_info() {
    local keystore_contents=$1

    while read -r line; do
        if [[ "$line" =~ "Owner: CN=" ]]; then
            cn=$(echo "$line" | awk -F '=' '{print $2}' | sed 's/,.*//')
        fi

        if [[ "$line" =~ Valid ]]; then
            expiration=$(echo "$line" | awk -F'until: ' '{print $2}' | xargs -I{} date -d "{}" +%s)
            if [ -n "$cn" ]; then
                cert_info["$cn"]=$expiration
            fi
        fi
    done <<< "$keystore_contents"
}

keystore_contents=$(keytool -list -v -keystore /home/organ/organx-ASP/config/truststore.jks -storepass asdasd 2>/dev/null)
extract_cert_info "$keystore_contents"

keystore_contents=$(keytool -list -v -keystore /home/organ/organx-ASP/config/keystore.jks -storepass asdasd 2>/dev/null)
extract_cert_info "$keystore_contents"

# Kiírjuk a tanúsítványok adatait JSON formátumban.
echo "{"
echo "  \"data\": ["
for key in "${!cert_info[@]}"; do
  json=$(printf '    {"{#CERT_CN}": "%s", "{#CERT_EXP}": "%s"},\n' "$key" "${cert_info[$key]}")
  echo "$json"
done
for file in $pem_files; do
  cn=$(openssl x509 -in $file -noout -subject | awk -F'CN = ' '{print $2}')
  expiry=$(date -d "$(openssl x509 -in $file -noout -enddate | cut -d= -f 2)" +%s)

  if [ "$file" == "$last_file" ]; then
    json=$(printf '    {"{#CERT_CN}": "%s", "{#CERT_EXP}": "%s"}\n' "$cn" "$expiry")
  else
    json=$(printf '    {"{#CERT_CN}": "%s", "{#CERT_EXP}": "%s"},\n' "$cn" "$expiry")
  fi

  echo "$json"
done
echo "  ]"
echo "}"
