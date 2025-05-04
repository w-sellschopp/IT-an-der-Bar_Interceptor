#!/bin/bash

set -e

# ─────────────────────────────
# Eingabe der Domain
# ─────────────────────────────
read -rp "Bitte gib die gewünschte Webadresse ein (Default: itanderbar.hkpig.de): " DOMAIN
DOMAIN=${DOMAIN:-itanderbar.hkpig.de}

NAMESPACE="itanderbar"
IMAGE_URL="https://raw.githubusercontent.com/it-and-der-bar/YouTube/refs/heads/main/logo-itanderbar.png"

echo "==> Namespace '$NAMESPACE' anlegen"
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

# ─────────────────────────────
# Deployment mit InitContainer
# ─────────────────────────────
echo "==> Deployment erstellen"
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: itander-web
  namespace: $NAMESPACE
spec:
  replicas: 1
  selector:
    matchLabels:
      app: itander
  template:
    metadata:
      labels:
        app: itander
    spec:
      initContainers:
        - name: fetch-logo
          image: curlimages/curl:v1.2
          command: ["sh", "-c"]
          args:
            - |
              curl -Lo /work/logo.png $IMAGE_URL && \
              echo '<!DOCTYPE html>' > /work/index.html && \
              echo '<html lang="de">' >> /work/index.html && \
              echo '<head>' >> /work/index.html && \
              echo '  <meta charset="UTF-8">' >> /work/index.html && \
              echo '  <title>IT AND DER BAR</title>' >> /work/index.html && \
              echo '  <style>' >> /work/index.html && \
              echo '    body { background:#f4f4f4; font-family:monospace; text-align:center; padding-top:50px; }' >> /work/index.html && \
              echo '    img { max-width:300px; border:3px solid #ddd; border-radius:12px; box-shadow:0 0 15px rgba(0,0,0,0.1); }' >> /work/index.html && \
              echo '    h1 { color:#444; margin-top:30px; font-size:24px; }' >> /work/index.html && \
              echo '    .links { margin-top:40px; }' >> /work/index.html && \
              echo '    .links a { display:inline-block; margin:0 10px; padding:8px 12px; text-decoration:none; color:#333; background:#fff; border:1px solid #ccc; border-radius:8px; transition:all 0.3s; }' >> /work/index.html && \
              echo '    .links a:hover { background:#222; color:#fff; border-color:#222; }' >> /work/index.html && \
              echo '    .footer { margin-top:60px; color:#aaa; font-size:12px; }' >> /work/index.html && \
              echo '  </style>' >> /work/index.html && \
              echo '</head>' >> /work/index.html && \
              echo '<body>' >> /work/index.html && \
              echo '  <img src="logo.png" alt="IT AND DER BAR Logo" />' >> /work/index.html && \
              echo '  <h1>Willkommen bei IT AND DER BAR</h1>' >> /work/index.html && \
              echo '  <p>Hosted proudly on k3s + nginx</p>' >> /work/index.html && \
              echo '  <div class="links">' >> /work/index.html && \
              echo '    <a href="https://www.youtube.com/@itanderbar" target="_blank">YouTube</a>' >> /work/index.html && \
              echo '    <a href="https://www.instagram.com/it_anderbar" target="_blank">Instagram</a>' >> /work/index.html && \
              echo '    <a href="https://github.com/it-and-der-bar/YouTube" target="_blank">GitHub Repo</a>' >> /work/index.html && \
              echo '  </div>' >> /work/index.html && \
              echo '  <div class="footer">mach nichts kaputt was du nicht selbst reparieren kannst...</div>' >> /work/index.html && \
              echo '</body>' >> /work/index.html && \
              echo '</html>' >> /work/index.html
          volumeMounts:
            - name: content
              mountPath: /work
      containers:
        - name: nginx
          image: nginx
          ports:
            - containerPort: 80
          volumeMounts:
            - name: content
              mountPath: /usr/share/nginx/html
      volumes:
        - name: content
          emptyDir: {}
EOF

# ─────────────────────────────
# Service
# ─────────────────────────────
echo "==> Service erstellen"
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: itander-svc
  namespace: $NAMESPACE
spec:
  selector:
    app: itander
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80
EOF

# ─────────────────────────────
# Ingress mit TLS
# ─────────────────────────────
echo "==> Ingress mit TLS anlegen"
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: itander-ingress
  namespace: $NAMESPACE
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
    cert-manager.io/cluster-issuer: letsencrypt-prod
spec:
  ingressClassName: nginx
  tls:
    - hosts:
        - $DOMAIN
      secretName: itanderbar-tls
  rules:
    - host: $DOMAIN
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: itander-svc
                port:
                  number: 80
EOF

echo "✅ Deployment erfolgreich! Aufrufbar unter: https://$DOMAIN"
