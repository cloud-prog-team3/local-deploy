#!/bin/bash

CRI=$1
CLUSTER=$2

if [ "-h" = "$1" ] || [ "--help" = "$1" ]; then
  echo "Usage: $0 [<container_runtime>] [<cluster_name>]"
  echo "Example: $0 docker kind"
  echo "Example: $0 podman"
  echo "Defaults:"
  echo "  <container_runtime> = docker"
  echo "  <cluster_name> = kind"
  exit 0
fi
if [ -z "$CLUSTER" ]; then
  CLUSTER="kind"
  echo "Using default cluster name: $CLUSTER"
fi
if [ -z "$CRI" ]; then
  CRI="docker"
  echo "Using default container runtime: $CRI"
fi

SUBNET=$($CRI network inspect $CLUSTER -f '{{(index .IPAM.Config 0).Subnet}}')
if [ $? -ne 0 ]; then
  echo "Error: Failed to get subnet from $CRI network inspect."
  exit 1
fi
BASE_IP=$(echo $SUBNET | cut -d. -f1-3)

IP_RANGE="${BASE_IP}.120-${BASE_IP}.130"
echo "Setting MetalLB IP range to: $IP_RANGE"

sed -i '/addresses:/!b;n;s/.*- .*/  - '"$IP_RANGE"'/g' res/metallb.yaml