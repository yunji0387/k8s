#!/bin/bash
# Run this to add cloud-optiplex.area87.uk as a trusted domain in Nextcloud
# Find your Nextcloud pod name first:
#   kubectl get pods -n homelab

POD=$(kubectl get pod -n homelab -l app=nextcloud -o jsonpath='{.items[0].metadata.name}')

kubectl exec -n homelab "$POD" -- su -s /bin/sh www-data -c "php occ config:system:set trusted_domains 1 --value=cloud-optiplex.area87.uk"

echo "Done. Verify with:"
echo "kubectl exec -n homelab $POD -- su -s /bin/sh www-data -c 'php occ config:system:get trusted_domains'"

