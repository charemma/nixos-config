import * as pulumi from "@pulumi/pulumi";
import * as k8s from "@pulumi/kubernetes";

const config = new pulumi.Config();

// ── attic ──────────────────────────────────────────────────────────────────

const atticJwtSecret = config.requireSecret("atticJwtSecret");

const atticNs = new k8s.core.v1.Namespace("attic", {
  metadata: { name: "attic" },
});

const credentials = new k8s.core.v1.Secret("attic-credentials", {
  metadata: {
    name: "attic-credentials",
    namespace: atticNs.metadata.name,
  },
  stringData: {
    ATTIC_SERVER_TOKEN_HS256_SECRET_BASE64: atticJwtSecret,
  },
});

const configMap = new k8s.core.v1.ConfigMap("attic-config", {
  metadata: {
    name: "attic-config",
    namespace: atticNs.metadata.name,
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
    namespace: atticNs.metadata.name,
  },
  spec: {
    accessModes: ["ReadWriteOnce"],
    resources: { requests: { storage: "20Gi" } },
  },
});

const atticLabels = { app: "attic" };

const deployment = new k8s.apps.v1.Deployment("attic", {
  metadata: {
    name: "attic",
    namespace: atticNs.metadata.name,
  },
  spec: {
    replicas: 1,
    selector: { matchLabels: atticLabels },
    template: {
      metadata: { labels: atticLabels },
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

const atticService = new k8s.core.v1.Service("attic", {
  metadata: {
    name: "attic",
    namespace: atticNs.metadata.name,
  },
  spec: {
    selector: atticLabels,
    ports: [{ port: 8080, targetPort: 8080 }],
  },
});

new k8s.networking.v1.Ingress("attic", {
  metadata: {
    name: "attic",
    namespace: atticNs.metadata.name,
    annotations: {
      "traefik.ingress.kubernetes.io/router.entrypoints": "websecure",
      "traefik.ingress.kubernetes.io/router.tls.certresolver": "letsencrypt",
      "traefik.ingress.kubernetes.io/buffering-maxrequestbodybytes": "0",
      "traefik.ingress.kubernetes.io/buffering-maxresponsebodybytes": "0",
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
                  name: atticService.metadata.name,
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

// ── argocd ─────────────────────────────────────────────────────────────────

const argoCDNs = new k8s.core.v1.Namespace("argocd", {
  metadata: { name: "argocd" },
});

const argoCD = new k8s.helm.v3.Release("argocd", {
  chart: "argo-cd",
  repositoryOpts: { repo: "https://argoproj.github.io/argo-helm" },
  namespace: argoCDNs.metadata.name,
  values: {
    configs: {
      params: {
        // TLS is terminated at Traefik ingress; ArgoCD runs plain HTTP internally
        "server.insecure": "true",
      },
    },
  },
}, { dependsOn: argoCDNs });

new k8s.networking.v1.Ingress("argocd", {
  metadata: {
    name: "argocd",
    namespace: argoCDNs.metadata.name,
    annotations: {
      "traefik.ingress.kubernetes.io/router.entrypoints": "websecure",
      "traefik.ingress.kubernetes.io/router.tls.certresolver": "letsencrypt",
    },
  },
  spec: {
    rules: [
      {
        host: "argocd.charemma.de",
        http: {
          paths: [
            {
              path: "/",
              pathType: "Prefix",
              backend: {
                service: {
                  name: "argocd-server",
                  port: { number: 80 },
                },
              },
            },
          ],
        },
      },
    ],
    tls: [{ hosts: ["argocd.charemma.de"] }],
  },
}, { dependsOn: argoCD });

// Root Application -- manages all apps in infra/vps/apps/ via GitOps
new k8s.apiextensions.CustomResource("root-app", {
  apiVersion: "argoproj.io/v1alpha1",
  kind: "Application",
  metadata: {
    name: "root",
    namespace: "argocd",
  },
  spec: {
    project: "default",
    source: {
      repoURL: "https://github.com/charemma/nixos-config",
      targetRevision: "HEAD",
      path: "infra/vps/apps",
    },
    destination: {
      server: "https://kubernetes.default.svc",
      namespace: "argocd",
    },
    syncPolicy: {
      automated: {
        prune: true,
        selfHeal: true,
      },
    },
  },
}, { dependsOn: argoCD });
