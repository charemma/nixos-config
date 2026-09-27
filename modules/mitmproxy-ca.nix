# mitmproxy-ca.nix -- trust the aiagent mitmproxy CA on client hosts.
#
# aiagent runs mitmproxy (it is always online); north and macbook route their
# HTTPS through it for bug-bounty / recon interception. For intercepted TLS to
# validate, those clients must trust mitmproxy's CA. Only the PUBLIC certificate
# lives here (certs/mitmproxy-ca-cert.pem) -- the private CA key never leaves
# aiagent's ~/.mitmproxy. A public CA cert grants nothing without that key, so
# it is safe in git even in a public repo.
#
# Trust scope is deliberately narrow: imported by client hosts only (north,
# macbook), NOT by the servers (vps, aiagent). A standing MITM CA in a server's
# system trust store is needless attack surface -- if the CA key ever leaked,
# every TLS connection those machines make could be transparently intercepted.
# aiagent itself does not need it: mitmproxy uses its own CA directly.
#
# security.pki.certificateFiles exists on both NixOS and nix-darwin (LnL7), so
# one option covers Linux and macOS with no platform branching.
#
# Rotating the CA: regenerate on aiagent (rm ~/.mitmproxy/mitmproxy-ca*, run
# mitmproxy once), copy the new mitmproxy-ca-cert.pem over the one here, rebuild
# the clients.
{ ... }:

{
  security.pki.certificateFiles = [ ./certs/mitmproxy-ca-cert.pem ];
}
