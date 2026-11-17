FROM ubuntu:22.04
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      python3 python3-pip python3-venv \
      sleuthkit autopsy binwalk foremost exiftool tshark testdisk yara scalpel \
      file xxd p7zip-full git curl ca-certificates vim less jq \
 && rm -rf /var/lib/apt/lists/*
RUN pip3 install --no-cache-dir volatility3 pycryptodome
RUN mkdir -p /cases
COPY README.md /cases/README.md
WORKDIR /cases
CMD ["sleep", "infinity"]
