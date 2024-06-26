{{- define "mongo-svc.fullname" -}}
{{- printf "%s-%s" .Release.Name .Chart.Name }}
{{- end -}}

{{- define "mongo.fullname" -}}
{{- printf "%s-mongo" .Release.Name }}
{{- end -}}

{{- define "mongo-pv.fullname" -}}
{{- printf "%s-%s-pv" .Release.Name .Chart.Name }}
{{- end -}}

{{- define "mongo-pvc.fullname" -}}
{{- printf "%s-%s-pvc" .Release.Name .Chart.Name }}
{{- end -}}

{{- define "network.policy.fullname" -}}
{{- printf "%s-deny-db-traffic" .Release.Name }}
{{- end -}}
