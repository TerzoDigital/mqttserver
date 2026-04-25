#!/bin/bash

./generate-certs.sh

echo "📂 Creating folders and adjusting ownership and permissions..."
if [[ ! -d data ]]; then
    mkdir data
else
    echo "⚠️ data folder already exists"
fi
if [[ ! -d log ]]; then
    mkdir log
else
    echo "⚠️ log folder already exists"
fi

# config
if [[ $(stat -c '%g' config) == "1883" ]]; then
    echo "⚠️ config folder already owned by 1883, no change made"
else
    sudo chown -R 1883:1883 config
    #chown 1883:1883 config/*
fi

# certs
if [[ $(stat -c '%g' certs) == "1883" ]]; then
    echo "⚠️ certs folder already owned by 1883, no change made"
else
    sudo chown -R 1883:1883 certs
    #chown 1883:1883 certs/*
fi

# data
if [[ $(stat -c '%g' data) == "1883" ]]; then
    echo "⚠️ data folder already owned by 1883, no change made"
else
    chmod 777 data
    sudo chown -R 1883:1883 data
fi

# log
if [[ $(stat -c '%g' log) == "1883" ]]; then
    echo "⚠️ log folder already owned by 1883, no change made"
else
    chmod 777 log
    sudo chown -R 1883:1883 log
fi

echo "✅ All setup is now complete."
