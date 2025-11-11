{{- define "mysql-cdc.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "mysql-cdc.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name (include "mysql-cdc.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "mysql-cdc.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" -}}
{{- end -}}

{{- define "mysql-cdc.labels" -}}
helm.sh/chart: {{ include "mysql-cdc.chart" . }}
{{ include "mysql-cdc.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{- define "mysql-cdc.selectorLabels" -}}
app.kubernetes.io/name: {{ include "mysql-cdc.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "mysql-cdc.headlessServiceName" -}}
{{- printf "%s-headless" (include "mysql-cdc.fullname" .) -}}
{{- end -}}

{{- define "mysql-cdc.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{ default (include "mysql-cdc.fullname" .) .Values.serviceAccount.name }}
{{- else -}}
{{ default "default" .Values.serviceAccount.name }}
{{- end -}}
{{- end -}}
