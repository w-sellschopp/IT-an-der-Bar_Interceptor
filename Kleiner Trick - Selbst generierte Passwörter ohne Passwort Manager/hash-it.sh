#!/bin/bash
read -p "Klartext: " text
hash_value=$(echo -n "$text" | md5sum | awk '{print $1}')
hash_sha256_value=$(echo -n "$text" | sha256sum | awk '{print $1}')

echo "$hash_value" >> test_own_hashes_md5
echo "$hash_sha256_value" >> test_own_hashes_sha256

echo "MD5   : $hash_value"
echo "SHA256: $hash_sha256_value"
