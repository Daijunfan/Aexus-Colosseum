FROM python:3.11-slim
ENV PYTHONDONTWRITEBYTECODE=1 PIP_NO_CACHE_DIR=1
RUN pip install flask garak
WORKDIR /app
COPY app.py /app/app.py
EXPOSE 8088
CMD ["python", "/app/app.py"]
