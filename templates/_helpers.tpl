{{/*
Expand the name of the chart.
*/}}
{{- define "spin-acme.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "spin-acme.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "spin-acme.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "spin-acme.labels" -}}
helm.sh/chart: {{ include "spin-acme.chart" . }}
{{ include "spin-acme.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "spin-acme.selectorLabels" -}}
app.kubernetes.io/name: {{ include "spin-acme.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{- define "spin-acme.existingWebsrvSelectorLabels" -}}
workloadselector: {{ printf "%s-%s" .Release.Namespace .Values.webServer.deploymentName }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "spin-acme.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "spin-acme.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Generate certificates for custom-metrics api server 
*/}}
{{- define "spin-acme.gen-certs" -}}
{{- $altNames := list ( printf "%s.%s" (include "spin-acme.name" .) .Release.Namespace ) ( printf "%s.%s.svc" (include "spin-acme.name" .) .Release.Namespace ) -}}
{{- $ca := genCA "spin-acme-ca" 365 -}}
{{- $cert := genSignedCert ( include "spin-acme.name" . ) nil $altNames 365 $ca -}}
tls.crt: {{ $cert.Cert | b64enc }}
tls.key: {{ $cert.Key | b64enc }}
{{- end -}}
