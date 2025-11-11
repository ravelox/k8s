# PostgreSQL CDC Helm Chart

This chart packages a single-instance PostgreSQL 16 deployment with configuration tuned for logical decoding / CDC collectors (e.g., Debezium, Kafka Connect). It replaces the previous static manifest with standard Helm primitives for easier customization.

## Installation

```sh
# Create/target the postgres namespace and install the release
helm upgrade --install postgres ./postgres/charts/postgres \
  --namespace postgres \
  --create-namespace
```

Key defaults:
- Install into any pre-created namespace (the example above uses `postgres`; omit `--create-namespace` if it already exists).
- Credentials are stored in a chart-managed secret unless you provide `auth.existingSecret` that exposes the keys `username`, `password`, and `database`.
- A `ReadWriteOnce` PVC sized at 10Gi backs `/var/lib/postgresql/data` (toggle with the `persistence` block).

## Configuration Highlights

| Value | Description | Default |
| --- | --- | --- |
| `auth.username/password/database` | Application user credentials | `app_user` / `changeMeSuperSecret` / `appdb` |
| `config.postgresqlConf` | Injected `postgresql.conf` enabling CDC (`wal_level=logical`, replication slots, etc.) | See `postgres/charts/postgres/values.yaml` |
| `config.pgHbaConf` | `pg_hba.conf` that permits logical replication clients (adjust CIDRs before production) | See `postgres/charts/postgres/values.yaml` |
| `persistence.size` | PVC size | `10Gi` |
| `service.type` / `service.port` | Service exposure within the cluster | `ClusterIP` / `5432` |

Inspect `postgres/charts/postgres/values.yaml` for the full surface area of overrides (resources, probes, tolerations, etc.).

## Post-Install Checks

1. Confirm the pod is ready:
   ```sh
   kubectl -n postgres rollout status deploy/postgres
   ```
2. Validate CDC settings:
   ```sh
   kubectl -n postgres exec deploy/postgres -- \
     psql -U app_user -d appdb -c "SHOW wal_level;"
   ```

Service DNS: `postgres.postgres.svc.cluster.local:5432` (release-scoped naming). Use these credentials in your CDC connector.

## Uninstall

```sh
helm uninstall postgres -n postgres
```
