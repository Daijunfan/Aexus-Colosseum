FROM ubuntu:22.04
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
 && apt-get install -y --no-install-recommends openssh-server vsftpd sudo ca-certificates \
 && rm -rf /var/lib/apt/lists/* \
 && mkdir -p /run/sshd
RUN useradd -m -s /bin/bash alice && echo 'alice:Password123' | chpasswd \
 && useradd -m -s /bin/bash bob && echo 'bob:Summer2024' | chpasswd \
 && echo 'root:toor' | chpasswd
RUN sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config \
 && sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
RUN printf 'listen=YES\nlisten_ipv6=NO\nanonymous_enable=NO\nlocal_enable=YES\nwrite_enable=YES\n' > /etc/vsftpd.conf
RUN printf 'AEXUS{weak_credentials_are_still_everywhere}\n' > /home/alice/flag.txt \
 && printf 'AEXUS{service_enumeration_pays_off}\n' > /home/bob/flag.txt \
 && chown alice:alice /home/alice/flag.txt && chown bob:bob /home/bob/flag.txt
EXPOSE 22 21
CMD service vsftpd start && exec /usr/sbin/sshd -D
