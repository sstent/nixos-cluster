#!/usr/bin/env bash
set -e

SOPS_FILE=".sops.yaml"
SECRETS_FILE="secrets/host-secrets.yaml"

if [ ! -f "$SOPS_FILE" ]; then
    echo "Error: $SOPS_FILE not found in current directory."
    echo "Please run this script from the root of the nixos-cluster repository."
    exit 1
fi

# We can parse the hosts directly from .sops.yaml or hardcode them
HOSTS=("odroid6" "odroid7" "odroid8" "opti1" "opti2" "opti3" "rpi3")

echo "Checking SOPS age keys for cluster hosts..."

UPDATED=false

for HOST in "${HOSTS[@]}"; do
    echo "----------------------------------------"
    echo "Checking host: $HOST"
    
    # Fetch the SSH key and convert to age key
    ACTUAL_KEY=$(ssh-keyscan -t ed25519 "$HOST" 2>/dev/null | grep ssh-ed25519 | cut -d" " -f2,3 | nix run nixpkgs#ssh-to-age 2>/dev/null || true)
    
    if [ -z "$ACTUAL_KEY" ]; then
        echo "⚠️  Could not fetch SSH key for $HOST. Is it online?"
        continue
    fi
    
    # Get uppercase name for yaml lookup (e.g. opti1 -> OPTI1)
    HOST_UPPER=$(echo "$HOST" | tr '[:lower:]' '[:upper:]')
    
    # Extract current key from .sops.yaml
    CURRENT_KEY=$(grep -E "&${HOST_UPPER}[[:space:]]+" "$SOPS_FILE" | awk '{print $3}' | tr -d '\r')
    
    if [ -z "$CURRENT_KEY" ]; then
        echo "⚠️  Host $HOST_UPPER not found in $SOPS_FILE."
        read -p "❓ Do you want to ADD this new key to .sops.yaml? (y/N) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            # Insert the new key definition just above creation_rules
            sed -i -e "/^creation_rules:/i \  - &${HOST_UPPER} ${ACTUAL_KEY}" "$SOPS_FILE"
            # Append the reference to all key_groups by inserting it after *adminkey (since adminkey is in all groups)
            sed -i -e "/- \*adminkey/a \      - *${HOST_UPPER}" "$SOPS_FILE"
            echo "✔️ Added $HOST_UPPER to .sops.yaml"
            UPDATED=true
        fi
        continue
    fi
    
    if [ "$ACTUAL_KEY" == "$CURRENT_KEY" ]; then
        echo "✅ Key matches! ($ACTUAL_KEY)"
    else
        echo "❌ Key mismatch!"
        echo "   .sops.yaml has: $CURRENT_KEY"
        echo "   Actual key is:  $ACTUAL_KEY"
        
        # Interactive questionnaire
        read -p "❓ Do you want to update .sops.yaml with the new key for $HOST? (y/N) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            sed -i "s/$CURRENT_KEY/$ACTUAL_KEY/g" "$SOPS_FILE"
            echo "✔️ Updated .sops.yaml"
            UPDATED=true
        fi
    fi
done

echo "----------------------------------------"
if [ "$UPDATED" = true ]; then
    echo "You have successfully updated .sops.yaml!"
    read -p "❓ Do you want to re-encrypt all files in the secrets/ directory now? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        for secret_file in secrets/*; do
            if [ -f "$secret_file" ]; then
                echo "Updating keys for $secret_file..."
                sops updatekeys "$secret_file" || echo "⚠️  Failed to update $secret_file (maybe not a SOPS file?)"
            fi
        done
        echo "✔️ All secrets updated!"
    else
        echo "Don't forget to run 'sops updatekeys' on your secret files later!"
    fi
else
    echo "Finished checking all hosts. No updates were required."
fi
