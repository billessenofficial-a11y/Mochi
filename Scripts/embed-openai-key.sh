#!/bin/sh

set -eu

environment_file="${SRCROOT}/.env.local"
output_file="${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/MochiOpenAIKey.txt"

/bin/mkdir -p "$(/usr/bin/dirname "${output_file}")"

if [ ! -f "${environment_file}" ]; then
  : > "${output_file}"
  echo "Mochi: no local OpenAI key was embedded."
  exit 0
fi

openai_key=$(/usr/bin/awk '
  /^[[:space:]]*OPENAI_API_KEY[[:space:]]*=/ {
    line = $0
    sub(/^[[:space:]]*OPENAI_API_KEY[[:space:]]*=[[:space:]]*/, "", line)
    print line
    exit
  }
' "${environment_file}")

case "${openai_key}" in
  \"*\") openai_key=${openai_key#\"}; openai_key=${openai_key%\"} ;;
  \'*\') openai_key=${openai_key#\'}; openai_key=${openai_key%\'} ;;
esac

if [ -z "${openai_key}" ]; then
  : > "${output_file}"
  echo "Mochi: OPENAI_API_KEY was not found in .env.local."
  exit 0
fi

/usr/bin/printf '%s' "${openai_key}" > "${output_file}"
/bin/chmod 600 "${output_file}"
echo "Mochi: embedded the temporary local OpenAI credential."
