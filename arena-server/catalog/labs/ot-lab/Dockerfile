FROM python:3.11-slim
ENV PIP_NO_CACHE_DIR=1
RUN pip install conpot pymodbus
RUN mkdir -p /var/log
EXPOSE 502 102 80 161/udp
CMD ["conpot", "--template", "default", "--logfile", "/var/log/conpot.log"]
