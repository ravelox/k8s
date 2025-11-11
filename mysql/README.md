# mysql-cdc Helm Chart

Deploy a single-instance MySQL 8.0 database configured for Change Data Capture (CDC) via row-based binary logging.

## Prerequisites

- Kubernetes 1.20+
- Helm 3.8+
- Persistent storage provisioner (if `persistence.enabled=true`)

## Installing the Chart

Set a secure root password (or supply an existing secret) before installing:

```bash
helm install my-db ./mysql-cdc \
  --set auth.rootPassword='replace-me'
```

Retrieve the generated secret if you allowed the chart to create it:

```bash
kubectl get secret my-db-mysql-cdc \
  -o jsonpath='{.data.mysql-root-password}' | base64 --decode && echo
```

Connect to the database:

```bash
kubectl run -it --rm mysql-client --image=mysql:8.0 --restart=Never -- \
  mysql -h my-db-mysql-cdc -P 3306 -u root -p
```

## CDC Configuration

Key defaults that enable CDC-friendly binlogs are managed through `values.yaml`:

- `binlog_format=ROW`
- `binlog_row_image=FULL`
- `binlog_checksum=CRC32`
- `sync_binlog=1`
- Retention window configured via `configuration.binlogRetentionHours`

Adjust these under the `configuration` block as needed for your replication or Debezium pipeline.

## Customization Highlights

- Credentials: provide `auth.*` values or reference an existing secret with `auth.existingSecret`.
- Storage: toggle `persistence.enabled` and size with `persistence.size`; set `storageClass` if required.
- Probes and resources: tune using the `startupProbe`, `livenessProbe`, `readinessProbe`, and `resources` sections.
- Additional Config: append to `configuration.extraMyCnf` for bespoke server directives.

Refer to `values.yaml` for the full list of configurable options.
