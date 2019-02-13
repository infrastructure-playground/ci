gcloud deployment-manager deployments create accounts --config=templates-bundle.yaml > keys

awk '/OUTPUT/ {for(i=1; i<=5; i++) {getline; print}}' keys

START=$(awk '/OUTPUT/ {print NR}' keys)
ENDPOINT=$(awk 'END{print NR}' keys)

KEYS_LINES=`expr $ENDPOINT - $START`

FILE_NAMES=($(awk '/OUTPUT/  {for(i=1; i<="'$KEYS_LINES'"; i++) {getline; print$1}}' keys)) # make into array
VALUES=($(awk '/OUTPUT/  {for(i=1; i<="'$KEYS_LINES'"; i++) {getline; print$2}}' keys))  # make into array

for index in ${!FILE_NAMES[*]}; do
  echo ${VALUES[$index]} | base64 -d > ${FILE_NAMES[$index]}.json  # Create Private Key JSON Files
  gsutil cp ${FILE_NAMES[$index]}.json gs://resources-practice-secrets-sb
done