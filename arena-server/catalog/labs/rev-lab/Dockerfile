FROM ubuntu:22.04
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      build-essential gcc gdb radare2 binutils strace ltrace file binwalk \
      python3 python3-pip python3-venv git curl ca-certificates vim less \
 && rm -rf /var/lib/apt/lists/*
RUN pip3 install --no-cache-dir capstone z3-solver angr
WORKDIR /challenges
COPY crackme1.c crackme2.c crackme3.c ./
RUN gcc -O0 -o crackme1 crackme1.c \
 && gcc -O2 -s -o crackme2 crackme2.c \
 && gcc -O1 -o crackme3 crackme3.c
RUN printf 'AEXUS{static_analysis_first}\n' > flag1.txt \
 && printf 'AEXUS{angr_loves_constraints}\n' > flag2.txt \
 && printf 'AEXUS{patience_is_a_weapon}\n' > flag3.txt
CMD ["sleep", "infinity"]
