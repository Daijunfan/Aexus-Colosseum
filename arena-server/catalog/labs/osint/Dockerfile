FROM python:3.11-slim
ENV DEBIAN_FRONTEND=noninteractive PIP_NO_CACHE_DIR=1
RUN apt-get update && apt-get install -y --no-install-recommends git build-essential ca-certificates \
 && rm -rf /var/lib/apt/lists/*
RUN pip install spiderfoot
EXPOSE 5001
CMD ["sf.py", "-l", "0.0.0.0:5001"]
