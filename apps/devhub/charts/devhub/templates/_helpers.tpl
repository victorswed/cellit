{{- define "devhub.name" -}}
{{- .Chart.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "devhub.fullname" -}}
{{- printf "%s-%s" .Release.Name (include "devhub.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
