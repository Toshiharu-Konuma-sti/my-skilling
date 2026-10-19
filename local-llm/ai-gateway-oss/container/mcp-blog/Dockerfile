FROM python:3.12-slim
WORKDIR /app
RUN pip install --no-cache-dir "mcp>=1.23,<2" "httpx>=0.28,<1"
COPY server.py .
USER nobody
CMD ["python", "server.py"]
