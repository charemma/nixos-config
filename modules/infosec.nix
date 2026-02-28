{ config, lib, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    # Recon
    nmap
    gobuster
    ffuf
    dirb
    nikto
    whatweb
    dnsutils
    whois

    # Exploitation
    sqlmap
    thc-hydra
    john
    hashcat
    metasploit

    # Networking
    netcat-openbsd
    socat
    proxychains
    openvpn

    # Web
    httpie

    # Scripting
    python3
    python3Packages.impacket
    evil-winrm
  ];
}
