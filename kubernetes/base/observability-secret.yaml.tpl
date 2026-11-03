apiVersion: v1
kind: Secret
metadata:
  name: motordesk-observability
  namespace: motordesk
type: Opaque
data:
  OTEL_EXPORTER_OTLP_HEADERS: "${OTEL_EXPORTER_OTLP_HEADERS_BASE64}"
