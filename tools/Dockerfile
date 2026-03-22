FROM python:3.11-slim

WORKDIR /app

# System libraries required by ultralytics / OpenCV on slim images
RUN apt-get update && apt-get install -y --no-install-recommends \
    libgl1 \
    libglib2.0-0 \
    libsm6 \
    libxext6 \
    libxrender-dev \
    && rm -rf /var/lib/apt/lists/*

# Install Python dependencies (cached layer)
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy model and server
COPY best.pt .
COPY ultralytics_server.py .

# Railway dynamically assigns PORT via env var
EXPOSE 8000

CMD ["sh", "-c", "uvicorn ultralytics_server:app --host 0.0.0.0 --port ${PORT:-8000}"]
