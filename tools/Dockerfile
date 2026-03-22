FROM python:3.11-slim

WORKDIR /app

# Install dependencies first (cached layer)
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy model and server
COPY best.pt .
COPY ultralytics_server.py .

# Railway dynamically assigns PORT via env var
EXPOSE 8000

CMD ["sh", "-c", "uvicorn ultralytics_server:app --host 0.0.0.0 --port ${PORT:-8000}"]
