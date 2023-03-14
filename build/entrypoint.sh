#!/bin/bash

NETWORK="mainnet"
VALIDATOR_PORT=3500

DATA_DIR="/home/user/nimbus-eth2/build/data"
VALIDATORS_DIR="${DATA_DIR}/validators"
TOKEN_FILE="${DATA_DIR}/auth-token"

# Create validators dir
mkdir -p ${VALIDATORS_DIR}

case $_DAPPNODE_GLOBAL_EXECUTION_CLIENT_MAINNET in
"geth.dnp.dappnode.eth")
    HTTP_ENGINE="http://geth.dappnode:8551"
    ;;
"nethermind.public.dappnode.eth")
    HTTP_ENGINE="http://nethermind.public.dappnode:8551"
    ;;
"erigon.dnp.dappnode.eth")
    HTTP_ENGINE="http://erigon.dappnode:8551"
    ;;
"besu.public.dappnode.eth")
    HTTP_ENGINE="http://besu.public.dappnode:8551"
    ;;
*)
    echo "Unknown value for _DAPPNODE_GLOBAL_EXECUTION_CLIENT_MAINNET: $_DAPPNODE_GLOBAL_EXECUTION_CLIENT_MAINNET"
    HTTP_ENGINE=$_DAPPNODE_GLOBAL_EXECUTION_CLIENT_MAINNET
    ;;
esac

if [ -n "$_DAPPNODE_GLOBAL_MEVBOOST_MAINNET" ] && [ "$_DAPPNODE_GLOBAL_MEVBOOST_MAINNET" == "true" ]; then
    echo "MEVBOOST is enabled"
    MEVBOOST_URL="http://mev-boost.mev-boost.dappnode:18550"
    EXTRA_OPTS="${EXTRA_OPTS} --payload-builder=true --payload-builder-url=${MEVBOOST_URL}"
fi

# Chek the env FEE_RECIPIENT_MAINNET has a valid ethereum address if not set to the null address
if [ -n "$FEE_RECIPIENT_MAINNET" ] && [[ "$FEE_RECIPIENT_MAINNET" =~ ^0x[a-fA-F0-9]{40}$ ]]; then
    FEE_RECIPIENT_ADDRESS="$FEE_RECIPIENT_MAINNET"
else
    echo "FEE_RECIPIENT_MAINNET is not set or is not a valid ethereum address, setting it to the null address"
    FEE_RECIPIENT_ADDRESS="0x0000000000000000000000000000000000000000"
fi

# Run checkpoint sync script if provided
[[ -n $CHECKPOINT_SYNC_URL ]] &&
    /home/user/nimbus-eth2/build/nimbus_beacon_node trustedNodeSync \
        --network=${NETWORK} \
        --trusted-node-url=${CHECKPOINT_SYNC_URL} \
        --backfill=false \
        --data-dir=//home/user/nimbus-eth2/build/data

#Apply graffiti limit to non-unicode characters
oLang=$LANG oLcAll=$LC_ALL
LANG=C LC_ALL=C 
graffitiString=${GRAFFITI:0:32}
LANG=$oLang LC_ALL=$oLcAll

exec -c /home/user/nimbus_beacon_node \
    --network=${NETWORK} \
    --data-dir=${DATA_DIR} \
    --tcp-port=$P2P_TCP_PORT \
    --udp-port=$P2P_UDP_PORT \
    --validators-dir=${VALIDATORS_DIR} \
    --log-level=${LOG_TYPE} \
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
    --graffiti="${graffitiString}" \
    --jwt-secret=/jwtsecret \
    --web3-url=$HTTP_ENGINE \
    --suggested-fee-recipient="${FEE_RECIPIENT_ADDRESS}" \
    $EXTRA_OPTS
