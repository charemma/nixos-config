# Sidecars for the Traefik pod that turn the access log into a live GoAccess
# dashboard. Returns chart values (deployment.additionalContainers etc.),
# rendered as JSON into the HelmChartConfig by default.nix.
#
# Traefik writes the access log to a file on a shared emptyDir:
# - access-log:   tails it to stdout (kubectl logs keeps working) and
#                 truncates it at maxLogBytes (safe, Traefik opens it O_APPEND)
# - goaccess:     downloads DB-IP Lite country/ASN databases, follows the log
#                 and writes a real-time HTML report with a websocket
# - goaccess-web: serves that HTML
#
# Not exposed via ingress. Access through the tailnet-only API:
#   kubectl -n kube-system port-forward deploy/traefik 8090 7890
#   http://localhost:8090
{ lib, logDir }:

let
  logFile = "${logDir}/access.log";
  reportDir = "/srv/report";
  dataDir = "/data";
  webPort = 8090;
  wsPort = 7890;
  maxLogBytes = 100 * 1000 * 1000;
  checkIntervalSeconds = 60;
  # Covers the previous month, DB-IP publishes a few days into a month.
  monthSeconds = 31 * 24 * 3600;

  goaccessImage = "allinurl/goaccess:1.12";
  busyboxImage = "busybox:1.37.0";

  # Traefik JSON access log. ClientHost is the TCP peer, or X-Forwarded-For
  # from trusted proxies (Cloudflare). Lines where a client prepended its own
  # X-Forwarded-For carry a list there and count as invalid in GoAccess.
  logFormat = builtins.toJSON {
    ClientHost = "%h";
    time = "%x";
    RequestMethod = "%m";
    RequestPath = "%U";
    RequestProtocol = "%H";
    DownstreamStatus = "%s";
    DownstreamContentSize = "%b";
    request_Referer = "%R";
    request_User-Agent = "%u";
    RequestHost = "%v";
    Duration = "%n";
  };
  # %x needs the full timestamp in both formats.
  timestampFormat = "%Y-%m-%dT%H:%M:%SZ";

  hardened = {
    allowPrivilegeEscalation = false;
    readOnlyRootFilesystem = true;
    capabilities.drop = [ "ALL" ];
  };

  accessLogScript = ''
    touch ${logFile}
    while sleep ${toString checkIntervalSeconds}; do
      if [ "$(stat -c %s ${logFile})" -gt ${toString maxLogBytes} ]; then
        truncate -s 0 ${logFile}
      fi
    done &
    exec tail -F -n +1 ${logFile}
  '';

  goaccessScript = ''
    fetch_db() {
      for month in "$(date +%Y-%m)" "$(date -d "@$(( $(date +%s) - ${toString monthSeconds} ))" +%Y-%m)"; do
        if wget -q -O ${dataDir}/$1.mmdb.gz "https://download.db-ip.com/free/dbip-$1-lite-$month.mmdb.gz"; then
          gunzip -f ${dataDir}/$1.mmdb.gz && return 0
        fi
      done
      echo "no DB-IP $1 database, continuing without it" >&2
      return 1
    }
    geo=""
    for kind in country asn; do
      fetch_db $kind && geo="$geo --geoip-database=${dataDir}/$kind.mmdb"
    done
    tail -F -n +1 ${logFile} | goaccess - $geo \
      --log-format='${logFormat}' \
      --date-format='${timestampFormat}' --time-format='${timestampFormat}' \
      --tz=Europe/Berlin --keep-last=30 --no-global-config \
      --real-time-html --addr=0.0.0.0 --port=${toString wsPort} \
      --ws-url=ws://localhost:${toString wsPort} \
      --html-report-title='charemma.de access log' \
      -o ${reportDir}/index.html
  '';
in {
  volumeMounts = [ { name = "access-logs"; mountPath = logDir; } ];

  volumes = [
    { name = "access-logs"; emptyDir.sizeLimit = "512Mi"; }
    { name = "goaccess-report"; emptyDir.sizeLimit = "64Mi"; }
    { name = "goaccess-data"; emptyDir.sizeLimit = "256Mi"; }
  ];

  containers = [
    {
      name = "access-log";
      image = busyboxImage;
      command = [ "/bin/sh" "-c" accessLogScript ];
      volumeMounts = [ { name = "access-logs"; mountPath = logDir; } ];
      securityContext = hardened;
      resources = {
        requests = { cpu = "5m"; memory = "8Mi"; };
        limits.memory = "32Mi";
      };
    }
    {
      name = "goaccess";
      image = goaccessImage;
      command = [ "/bin/sh" "-c" goaccessScript ];
      ports = [ { name = "goaccess-ws"; containerPort = wsPort; } ];
      volumeMounts = [
        { name = "access-logs"; mountPath = logDir; readOnly = true; }
        { name = "goaccess-report"; mountPath = reportDir; }
        { name = "goaccess-data"; mountPath = dataDir; }
      ];
      env = [ { name = "TMPDIR"; value = dataDir; } ];
      securityContext = hardened;
      resources = {
        requests = { cpu = "10m"; memory = "32Mi"; };
        limits.memory = "256Mi";
      };
    }
    {
      name = "goaccess-web";
      image = busyboxImage;
      command = [ "httpd" "-f" "-p" (toString webPort) "-h" reportDir ];
      ports = [ { name = "goaccess-web"; containerPort = webPort; } ];
      volumeMounts = [ { name = "goaccess-report"; mountPath = reportDir; readOnly = true; } ];
      securityContext = hardened;
      resources = {
        requests = { cpu = "5m"; memory = "8Mi"; };
        limits.memory = "32Mi";
      };
    }
  ];
}
