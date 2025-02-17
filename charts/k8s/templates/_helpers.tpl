{{/* vim: set filetype=mustache: */}}
{{/*
Expand the name of the chart.
*/}}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "vcluster.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Whether the ingressclasses syncer should be enabled
*/}}
{{- define "vcluster.syncIngressclassesEnabled" -}}
{{- if or
    (.Values.sync.ingressclasses).enabled
    (and
        .Values.sync.ingresses.enabled
        (not .Values.sync.ingressclasses)) -}}
    {{- true -}}
{{- end -}}
{{- end -}}

{{/*
Whether to create a cluster role or not
*/}}
{{- define "vcluster.createClusterRole" -}}
{{- if or
    (not
        (empty (include "vcluster.serviceMapping.fromHost" . )))
    (not
        (empty (include "vcluster.plugin.clusterRoleExtraRules" . )))
    (not
        (empty (include "vcluster.generic.clusterRoleExtraRules" . )))
    .Values.rbac.clusterRole.create
    .Values.sync.hoststorageclasses.enabled
    (index
        ((index .Values.sync "legacy-storageclasses") | default (dict "enabled" false))
    "enabled")
    (include "vcluster.syncIngressclassesEnabled" . )
	.Values.pro
    .Values.sync.nodes.enabled
    .Values.sync.persistentvolumes.enabled
    .Values.sync.storageclasses.enabled
    .Values.sync.priorityclasses.enabled
    .Values.sync.volumesnapshots.enabled
    .Values.proxy.metricsServer.nodes.enabled
    .Values.multiNamespaceMode.enabled
    .Values.coredns.plugin.enabled -}}
    {{- true -}}
{{- end -}}
{{- end -}}

{{- define "vcluster.clusterRoleName" -}}
{{- printf "vc-%s-v-%s" .Release.Name .Release.Namespace | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "vcluster.clusterRoleNameMultinamespace" -}}
{{- printf "vc-mn-%s-v-%s" .Release.Name .Release.Namespace | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Syncer flags for enabling/disabling controllers
Prints only the flags that modify the defaults:
- when default controller has enabled: false => `- "--sync=-controller`
- when non-default controller has enabled: true => `- "--sync=controller`
*/}}
{{- define "vcluster.syncer.syncArgs" -}}
{{- $defaultEnabled := list "services" "configmaps" "secrets" "endpoints" "pods" "events" "persistentvolumeclaims" "fake-nodes" "fake-persistentvolumes" -}}
{{- if and (hasKey .Values.sync.nodes "enableScheduler") .Values.sync.nodes.enableScheduler -}}
    {{- $defaultEnabled = concat $defaultEnabled (list "csinodes" "csidrivers" "csistoragecapacities" ) -}}
{{- end -}}
{{- range $key, $val := .Values.sync }}
{{- if and (has $key $defaultEnabled) (not $val.enabled) }}
- --sync=-{{ $key }}
{{- else if and (not (has $key $defaultEnabled)) ($val.enabled)}}
{{- if eq $key "legacy-storageclasses" }}
- --sync=hoststorageclasses
{{- else }}
- --sync={{ $key }}
{{- end -}}
{{- end -}}
{{- end -}}
{{- if not (include "vcluster.syncIngressclassesEnabled" . ) }}
- --sync=-ingressclasses
{{- end -}}
{{- end -}}

{{/*
  Cluster role rules defined by plugins
*/}}
{{- define "vcluster.plugin.clusterRoleExtraRules" -}}
{{- range $key, $container := .Values.plugin }}
{{- if $container.rbac }}
{{- if $container.rbac.clusterRole }}
{{- if $container.rbac.clusterRole.extraRules }}
{{- range $ruleIndex, $rule := $container.rbac.clusterRole.extraRules }}
- {{ toJson $rule }}
{{- end }}
{{- end }}
{{- end }}
{{- end }}
{{- end }}
{{- end -}}

{{/*
  Cluster role rules defined in generic syncer
*/}}
{{- define "vcluster.generic.clusterRoleExtraRules" -}}
{{- if .Values.sync.generic.clusterRole }}
{{- if .Values.sync.generic.clusterRole.extraRules}}
{{- range $ruleIndex, $rule := .Values.sync.generic.clusterRole.extraRules }}
- {{ toJson $rule }}
{{- end }}
{{- end }}
{{- end }}
{{- end -}}

{{/*
  Role rules defined by plugins
*/}}
{{- define "vcluster.plugin.roleExtraRules" -}}
{{- range $key, $container := .Values.plugin }}
{{- if $container.rbac }}
{{- if $container.rbac.role }}
{{- if $container.rbac.role.extraRules }}
{{- range $ruleIndex, $rule := $container.rbac.role.extraRules }}
- {{ toJson $rule }}
{{- end }}
{{- end }}
{{- end }}
{{- end }}
{{- end }}
{{- end -}}

{{/*
  Role rules defined in generic syncer
*/}}
{{- define "vcluster.generic.roleExtraRules" -}}
{{- if .Values.sync.generic.role }}
{{- if .Values.sync.generic.role.extraRules}}
{{- range $ruleIndex, $rule := .Values.sync.generic.role.extraRules }}
- {{ toJson $rule }}
{{- end }}
{{- end }}
{{- end }}
{{- end -}}

{{/*
  Virtual cluster service mapping
*/}}
{{- define "vcluster.serviceMapping.fromVirtual" -}}
{{- range $key, $value := .Values.mapServices.fromVirtual }}
- '--map-virtual-service={{ $value.from }}={{ $value.to }}'
{{- end }}
{{- end -}}

{{/*
  Host cluster service mapping
*/}}
{{- define "vcluster.serviceMapping.fromHost" -}}
{{- range $key, $value := .Values.mapServices.fromHost }}
- '--map-host-service={{ $value.from }}={{ $value.to }}'
{{- end }}
{{- end -}}


{{/*
  deployment kind
*/}}
{{- define "vcluster.kind" -}}
{{ if and .Values.embeddedEtcd.enabled .Values.pro }}StatefulSet{{ else }}Deployment{{ end }}
{{- end -}}

{{/*
  service name for statefulset
*/}}
{{- define "vcluster.statefulset.serviceName" }}
{{- if .Values.embeddedEtcd.enabled }}
serviceName: {{ .Release.Name }}-headless
{{- end }}
{{- end -}}

{{/*
  volumeClaimTemplate
*/}}
{{- define "vcluster.statefulset.volumeClaimTemplate" }}
{{- if .Values.embeddedEtcd.enabled }}
{{- if .Values.autoDeletePersistentVolumeClaims }}
{{- if ge (int .Capabilities.KubeVersion.Minor) 27 }}
persistentVolumeClaimRetentionPolicy:
  whenDeleted: Delete
{{- end }}
{{- end }}
{{- if (hasKey .Values "volumeClaimTemplates") }}
volumeClaimTemplates:
{{ toYaml .Values.volumeClaimTemplates | indent 4 }}
{{- else if .Values.syncer.storage.persistence }}
volumeClaimTemplates:
  - metadata:
      name: data
    spec:
      accessModes: [ "ReadWriteOnce" ]
      {{- if .Values.syncer.storage.className }}
      storageClassName: {{ .Values.syncer.storage.className }}
      {{- end }}
      resources:
        requests:
          storage: {{ .Values.syncer.storage.size }}
{{- end }}
{{- end }}
{{- end -}}


{{/*
  deployment strategy
*/}}
{{- define "vcluster.deployment.strategy" }}
{{- if not .Values.embeddedEtcd.enabled }}
strategy:
  rollingUpdate:
    maxSurge: 1
    {{- if (eq (int .Values.syncer.replicas) 1) }}
    maxUnavailable: 0
    {{- else }}
    maxUnavailable: 1
    {{- end }}
  type: RollingUpdate
{{- end }}
{{- end -}}
