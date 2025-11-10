# Custom CA Import Job

This repository contains a Kubernetes `Job` manifest (`job-cacerts-import.yaml`) that copies the cluster Java truststore into a hostPath directory, temporarily loosens permissions to add a custom certificate with `keytool`, and then restores the original file mode.

## Applying the Job

1. Place the certificate you want to import in the directory that backs the hostPath volume (defaults to `/vagrant/certs/shared`).
2. Apply the manifest:
   ```sh
   kubectl apply -f job-cacerts-import.yaml
   ```

## Monitoring and Logs

- Wait for completion and stream status changes:
  ```sh
  kubectl wait --for=condition=complete --timeout=120s job/custom-root-ca-insert
  ```
- Fetch logs from the most recent pod created by the job:
  ```sh
  kubectl logs -l job-name=custom-root-ca-insert --container custom-ca-root-insert
  ```

If your cluster uses a TTL controller or log rotation, grab the logs promptly after completion.
