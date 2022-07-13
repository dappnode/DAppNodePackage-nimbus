#!/bin/bash

CLIENT="nimbus"
NETWORK="prater"
VALIDATOR_PORT=3500
WEB3SIGNER_API="http://web3signer.web3signer-${NETWORK}.dappnode:9000"

DATA_DIR="/home/user/nimbus-eth2/build/data"
VALIDATORS_DIR="${DATA_DIR}/validators"
TOKEN_FILE="${DATA_DIR}/auth-token"

# Create validators dir
mkdir -p ${VALIDATORS_DIR}

WEB3SIGNER_RESPONSE=$(curl -s -w "%{http_code}" -X GET -H "Content-Type: application/json" -H "Host: beacon-validator.${CLIENT}-${NETWORK}.dappnode" "${WEB3SIGNER_API}/eth/v1/keystores")
HTTP_CODE=${WEB3SIGNER_RESPONSE: -3}
CONTENT=$(echo "${WEB3SIGNER_RESPONSE}" | head -c-4)
if [ "${HTTP_CODE}" == "403" ] && [ "${CONTENT}" == "*Host not authorized*" ]; then
    echo "${CLIENT} is not authorized to access the Web3Signer API. Start without pubkeys"
elif [ "$HTTP_CODE" != "200" ]; then
    echo "Failed to get keystores from web3signer, HTTP code: ${HTTP_CODE}, content: ${CONTENT}"
else
    PUBLIC_KEYS_WEB3SIGNER=($(echo "${CONTENT}" | jq -r 'try .data[].validating_pubkey'))
    if [ ${#PUBLIC_KEYS_WEB3SIGNER[@]} -gt 0 ]; then
        echo "found validators in web3signer, starting vc with pubkeys: ${PUBLIC_KEYS_WEB3SIGNER[*]}"
        for PUBLIC_KEY in "${PUBLIC_KEYS_WEB3SIGNER[@]}"; do
            # Docs: https://github.com/status-im/nimbus-eth2/pull/3077#issue-1049195359
            # create a keystore file with the following format
            # {
            # "version": "1",
            # "description": "This is simple remote keystore file",
            # "type": "web3signer",
            # "pubkey": "0x8107ff6a5cfd1993f0dc19a6a9ec7dc742a528dd6f2e3e10189a4a6fc489ae6c7ba9070ea4e2e328f0d20b91cc129733",
            # "remote": "http://127.0.0.1:15052",
            # "ignore_ssl_verification": true
            # }

            echo "creating keystore for pubkey: ${PUBLIC_KEY}"
            mkdir -p "${VALIDATORS_DIR}"/"${PUBLIC_KEY}"
            echo "{\"version\": 1,\"description\":\"This is simple remote keystore file\",\"type\":\"web3signer\",\"pubkey\":\"${PUBLIC_KEY}\",\"remote\":\"${WEB3SIGNER_API}\",\"ignore_ssl_verification\":true}" >/home/user/nimbus-eth2/build/data/validators/${PUBLIC_KEY}/remote_keystore.json
        done
    fi
fi

# Run checkpoint sync script if provided
[[ -n $CHECKPOINT_SYNC_URL ]] &&
    /home/user/nimbus-eth2/build/nimbus_beacon_node trustedNodeSync \
        --network=${NETWORK} \
        --trusted-node-url=${CHECKPOINT_SYNC_URL} \
        --backfill=false \
        --data-dir=//home/user/nimbus-eth2/build/data
[[ -n $WEB3_BACKUP_URL ]] && EXTRA_OPTS="--web3-url=${WEB3_BACKUP_URL} ${EXTRA_OPTS}"

exec -c /home/user/nimbus-eth2/build/nimbus_beacon_node \
    --network=${NETWORK} \
    --data-dir=${DATA_DIR} \
    --validators-dir=${VALIDATORS_DIR} \
    --log-level=info \
    --rest \
    --rest-port=4500 \
    --rest-address=0.0.0.0 \
    --metrics \
    --metrics-address=0.0.0.0 \
    --metrics-port=8008 \
    --keymanager \
    --keymanager-port=${VALIDATOR_PORT} \
    --keymanager-address=0.0.0.0 \
    --keymanager-token-file=${TOKEN_FILE} \
    --graffiti="$GRAFFITI" \
    --suggested-fee-recipient="${FEE_RECIPIENT_ADDRESS}" \
    $EXTRA_OPTS
