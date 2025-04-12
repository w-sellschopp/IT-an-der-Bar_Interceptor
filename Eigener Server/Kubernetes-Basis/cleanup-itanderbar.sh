#!/bin/bash

set -e

NAMESPACE="itanderbar"

echo "==> Namespace '$NAMESPACE' löschen"
kubectl delete namespace "$NAMESPACE" --ignore-not-found

echo "✅ Bereinigt"
