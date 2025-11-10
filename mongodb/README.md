# MongoDB Helm Chart

This chart deploys a three-member MongoDB replica set on Kubernetes using a `StatefulSet`, persistent volumes, and an init `Job` that bootstraps the replica set.

## Prerequisites
- Helm 3.8+ installed locally.
- Kubernetes cluster with storage provisioner (or provide a storage class via `persistence.storageClass`).
- Optional: an existing `Secret` containing MongoDB credentials and replica-set key.

## Quick Start
```bash
# Render manifests locally (dry run)
helm template my-release charts/mongodb

# Install into the current kube context
helm install my-release charts/mongodb
```

Helm creates:
- StatefulSet with three MongoDB pods (`replicaCount` configurable).
- Headless and ClusterIP services for intra-cluster and client access.
- Secret with root credentials and replica-set key (unless you provide `auth.existingSecret`).
- Job that runs `rs.initiate` once all pods are reachable.

## Configuration
Set values inline or via a custom `values.yaml`.

```bash
# Generate a valid replica-set key (Base64 alphabet, <=1024 chars)
openssl rand -base64 756 | tr -d '\n' | cut -c1-1024 > replset.key

helm install my-release charts/mongodb \
  --namespace mongodb \
  --create-namespace \
  --set auth.password='strong-password' \
  --set auth.replicaSetKey="$(cat replset.key)" \
  --set persistence.size=20Gi

# Enable per-member NodePorts advertised via 192.168.60.10:32017-32019
helm install my-release charts/mongodb \
  --namespace mongodb \
  --create-namespace \
  --set auth.password='strong-password' \
  --set auth.replicaSetKey="$(cat replset.key)" \
  --set exposure.perMemberNodePort.enabled=true \
  --set exposure.perMemberNodePort.externalIP='192.168.60.10' \
  --set exposure.perMemberNodePort.baseNodePort=32017

# Enable TLS with a cert-manager issuer
helm install my-release charts/mongodb \
  --namespace mongodb \
  --create-namespace \
  --set auth.password='strong-password' \
  --set auth.replicaSetKey="$(cat replset.key)" \
  --set tls.enabled=true \
  --set tls.certManager.issuerRef.name='my-cluster-issuer'
```

Key values:
- `auth.enabled`: enables root credentials and keyfile (`true` by default).
- `auth.username` / `auth.password`: credentials stored in the generated secret.
- `auth.replicaSetKey`: keyfile used for internal replica-set authentication. Must be 6–1024 characters drawn only from the Base64 set (`A–Z`, `a–z`, `0–9`, `+`, `/`, `=`).
- `auth.existingSecret`: reference an existing secret with `username`, `password`, and `replicaSetKey` keys to avoid Helm-managed secrets.
- `tls.enabled`: enable server-side TLS with certificates sourced from cert-manager or an existing secret.
- `tls.mode`: TLS mode passed to `mongod` (`requireTLS` by default).
- `tls.existingSecret`: reference an existing TLS secret containing `tls.crt`, `tls.key`, and `ca.crt` instead of provisioning one via cert-manager.
- `tls.certManager.*`: configure issuer reference, secret naming, rotation windows, and optional SAN overrides for auto-generated certificates.
- `tls.allowConnectionsWithoutCertificates`: allow username/password clients (including replica-set peers) to connect without presenting a client TLS certificate; defaults to `true`.
- `replicaCount`: number of stateful replica members (default `3`).
- `service.type`: defaults to `LoadBalancer` for external client access. Switch to `ClusterIP` for internal-only usage.
- `service.loadBalancerIP` / `service.loadBalancerSourceRanges`: optional controls for the external load balancer.
- `service.nodePort`: set when you need a fixed NodePort (integer in 30000-32767) for the LoadBalancer service.
- `service.externalIPs`, `service.clusterIP`, `service.clusterIPs`: explicitly pin additional dataplane addresses (also copied into the TLS certificate SANs).
- `exposure.perMemberNodePort.*`: enable to publish each replica on the same external IP with incrementing NodePorts (e.g., 32017, 32018, 32019) and provide a client-facing host list.
- `exposure.perMemberNodePort.nodeIPs`: optional list of node IPs clients might dial directly via the NodePort services; each entry is added to the TLS certificate SANs.
- `persistence.*`: control PVC provisioning; set `persistence.enabled=false` to use ephemeral storage (not recommended for production).
- `resources`: tune container requests and limits.
- `initContainers.keyfile.*`: image settings for the keyfile staging init container (override if BusyBox is not allowed in your cluster).

## TLS with cert-manager
Setting `tls.enabled=true` switches the StatefulSet and replica-set bootstrap Job to `requireTLS`. When `tls.existingSecret` is empty the chart provisions a cert-manager `Certificate` resource:
- The issuer reference comes from `tls.certManager.issuerRef` (set `name`, optionally `kind`/`group`).
- The generated `Secret` defaults to `<release>-mongodb-tls` but can be overridden with `tls.certManager.secretName`.
- All MongoDB service names (ClusterIP, headless, and optional per-member NodePort services) and every configured IP address (`service.loadBalancerIP`, `service.externalIPs`, `service.clusterIP`, `service.clusterIPs`, `exposure.perMemberNodePort.externalIP`, `exposure.perMemberNodePort.nodeIPs`, plus any extras in `tls.certManager.additional*`) are added as DNS Subject Alternative Names. IPs are also included in the certificate `ipAddresses` list.
- The chart annotates each MongoDB service with `cert-manager.io/cluster-issuer` using `tls.certManager.issuerRef.name` when it is set.
- The secret must expose `tls.crt`, `tls.key`, and `ca.crt`. An init container combines the key and certificate into `/etc/mongodb/tls/tls.pem` before `mongod` starts.
- If `ca.crt` is missing (common with some ACME issuers), the pods reuse `tls.crt` as the CA bundle so MongoDB still launches. Provide a dedicated CA certificate when mutual TLS or strict chain validation is required.

Clients should connect with TLS enabled, for example:
```bash
mongosh "mongodb://root:strong-password@my-release-mongodb.mongodb.svc.cluster.local/admin?replicaSet=mongodb-rs" --tls --tlsCAFile ca.crt
```

Edit `charts/mongodb/values.yaml` or supply overrides with `-f`:
```bash
helm install my-release charts/mongodb -f my-values.yaml --namespace mongodb --create-namespace
```

## Post-Install
Retrieve the generated credentials:
```bash
USER=$(kubectl -n mongodb get secret my-release-mongodb-auth -o jsonpath='{.data.username}' | base64 --decode)
PASS=$(kubectl -n mongodb get secret my-release-mongodb-auth -o jsonpath='{.data.password}' | base64 --decode)
```

Port-forward to the primary:
```bash
kubectl -n mongodb port-forward statefulset/my-release-mongodb 27017:27017
mongosh "mongodb://${USER}:${PASS}@localhost:27017/admin?replicaSet=$(helm get values my-release -n mongodb -o json | jq -r '.auth.replicaSetName // "mongodb-rs"')"
rs.status()
```

## Upgrades
- Update `values.yaml` or override flags.
- Run `helm upgrade my-release charts/mongodb --namespace mongodb`.
- The init Job is annotated to run once; if you scale the replica set after the first install, MongoDB handles replica addition automatically.

## Uninstall
```bash
helm uninstall my-release --namespace mongodb
```

Depending on your storage class, persistent volume claims may remain. Remove them manually if required:
```bash
kubectl delete pvc -l app.kubernetes.io/instance=my-release -n mongodb
```
