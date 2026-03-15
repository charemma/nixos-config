import * as pulumi from "@pulumi/pulumi";
import * as k8s from "@pulumi/kubernetes";

const config = new pulumi.Config();
const atticJwtSecret = config.requireSecret("atticJwtSecret");

const ns = new k8s.core.v1.Namespace("attic", {
  metadata: { name: "attic" },
});

const credentials = new k8s.core.v1.Secret("attic-credentials", {
  metadata: {
    name: "attic-credentials",
    namespace: ns.metadata.name,
  },
  stringData: {
    ATTIC_SERVER_TOKEN_HS256_SECRET_BASE64: atticJwtSecret,
  },
});

const configMap = new k8s.core.v1.ConfigMap("attic-config", {
  metadata: {
    name: "attic-config",
    namespace: ns.metadata.name,
  },
  data: {
    "server.toml": `
listen = "[::]:8080"
api-endpoint = "https://nix.charemma.de/"

[database]
url = "sqlite:///data/attic.db?mode=rwc"

[storage]
type = "local"
path = "/data/storage"

[chunking]
nar-size-threshold = 65536
min-size = 16384
avg-size = 65536
max-size = 262144

[compression]
type = "zstd"

[garbage-collection]
interval = "12 hours"
default-retention-period = "6 months"
`.trim(),
  },
});

const pvc = new k8s.core.v1.PersistentVolumeClaim("attic-data", {
  metadata: {
    name: "attic-data",
    namespace: ns.metadata.name,
  },
  spec: {
    accessModes: ["ReadWriteOnce"],
    resources: { requests: { storage: "20Gi" } },
  },
});

const appLabels = { app: "attic" };

const deployment = new k8s.apps.v1.Deployment("attic", {
  metadata: {
    name: "attic",
    namespace: ns.metadata.name,
  },
  spec: {
    replicas: 1,
    selector: { matchLabels: appLabels },
    template: {
      metadata: { labels: appLabels },
      spec: {
        containers: [
          {
            name: "attic",
            image: "ghcr.io/zhaofengli/attic:latest",
            args: ["-f", "/etc/attic/server.toml", "--mode", "monolithic"],
            ports: [{ containerPort: 8080 }],
            envFrom: [{ secretRef: { name: credentials.metadata.name } }],
            volumeMounts: [
              { name: "config", mountPath: "/etc/attic" },
              { name: "data", mountPath: "/data" },
            ],
            readinessProbe: {
              httpGet: { path: "/", port: 8080 },
              initialDelaySeconds: 5,
              periodSeconds: 10,
            },
          },
        ],
        volumes: [
          { name: "config", configMap: { name: configMap.metadata.name } },
          { name: "data", persistentVolumeClaim: { claimName: pvc.metadata.name } },
        ],
      },
    },
  },
});

const service = new k8s.core.v1.Service("attic", {
  metadata: {
    name: "attic",
    namespace: ns.metadata.name,
  },
  spec: {
    selector: appLabels,
    ports: [{ port: 8080, targetPort: 8080 }],
  },
});

new k8s.networking.v1.Ingress("attic", {
  metadata: {
    name: "attic",
    namespace: ns.metadata.name,
    annotations: {
      "traefik.ingress.kubernetes.io/router.entrypoints": "websecure",
      "traefik.ingress.kubernetes.io/router.tls.certresolver": "letsencrypt",
    },
  },
  spec: {
    rules: [
      {
        host: "nix.charemma.de",
        http: {
          paths: [
            {
              path: "/",
              pathType: "Prefix",
              backend: {
                service: {
                  name: service.metadata.name,
                  port: { number: 8080 },
                },
              },
            },
          ],
        },
      },
    ],
    tls: [{ hosts: ["nix.charemma.de"] }],
  },
});
