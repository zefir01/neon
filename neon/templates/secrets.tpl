apiVersion: v1
kind: Secret
metadata:
  name: postgres-password
type: Opaque
data:
  password: ${postgres-password}