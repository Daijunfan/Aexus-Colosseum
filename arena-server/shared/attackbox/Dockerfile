FROM kalilinux/kali-rolling

ENV DEBIAN_FRONTEND=noninteractive

# The upstream Kali mirror list includes hosts that are not reachable from
# every network.  Pin a single well-mirrored source so the build is
# deterministic (and retry transient resolution failures).
RUN rm -f /etc/apt/sources.list /etc/apt/sources.list.d/* \
 && printf 'deb http://mirrors.tuna.tsinghua.edu.cn/kali kali-rolling main contrib non-free non-free-firmware\n' > /etc/apt/sources.list

# A curated red-team workstation.  Kept in one layer so rebuilds stay cheap and
# the image stays reproducible from the Kali rolling snapshot at build time.
RUN apt-get -o Acquire::Retries=5 update \
 && apt-get install -y --no-install-recommends \
      kali-linux-headless \
      metasploit-framework \
      exploitdb \
      impacket-scripts \
      crackmapexec \
      responder \
      enum4linux \
      smbclient \
      ldap-utils \
      nmap sqlmap hydra gobuster ffuf nikto dirb john hashcat \
      netcat-traditional socat tcpdump dnsutils whois curl wget git \
      python3 python3-pip python3-dev build-essential libffi-dev libssl-dev \
      swig pkg-config vim tmux jq less iputils-ping iproute2 net-tools \
      openssh-client wordlists \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*

# Python tooling that is not always packaged: AD attack paths and cloud CLIs.
# PyPI through a mirror that resolves from this network; upstream
# files.pythonhosted.org is not reachable without a proxy here.
RUN pip install --no-cache-dir --break-system-packages --prefer-binary \
      -i https://pypi.tuna.tsinghua.edu.cn/simple \
      requests certipy-ad bloodhound impacket \
 && pip install --no-cache-dir --break-system-packages --prefer-binary \
      -i https://pypi.tuna.tsinghua.edu.cn/simple pwntools

RUN mkdir -p /shared/attackbox && \
    echo 'source /usr/share/metasploit-framework/scripts/msfconsole.rc' >/dev/null || true

WORKDIR /shared/attackbox
CMD ["sleep", "infinity"]
