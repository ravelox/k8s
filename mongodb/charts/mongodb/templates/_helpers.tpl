{{- define "mongodb.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "mongodb.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name (include "mongodb.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "mongodb.labels" -}}
app.kubernetes.io/name: {{ include "mongodb.name" . }}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version | replace "+" "_" }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{- define "mongodb.selectorLabels" -}}
app.kubernetes.io/name: {{ include "mongodb.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "mongodb.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (include "mongodb.fullname" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{- define "mongodb.replicaSetName" -}}
{{- default (printf "%s-rs" (include "mongodb.name" .)) .Values.auth.replicaSetName -}}
{{- end -}}

{{- define "mongodb.replicaCount" -}}
{{- $replicaSet := .Values.replicaSet | default dict -}}
{{- $raw := coalesce $replicaSet.memberCount .Values.replicaCount 3 -}}
{{- $count := max 1 (int $raw) -}}
{{- printf "%d" $count -}}
{{- end -}}

{{- define "mongodb.tlsSecretName" -}}
{{- if .Values.tls.existingSecret -}}
{{- .Values.tls.existingSecret -}}
{{- else if and .Values.tls.enabled (ne (default "" .Values.tls.certManager.secretName) "") -}}
{{- .Values.tls.certManager.secretName -}}
{{- else -}}
{{- printf "%s-tls" (include "mongodb.fullname" .) -}}
{{- end -}}
{{- end -}}
