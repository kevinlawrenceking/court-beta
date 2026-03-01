# Python worker for OCR, AI summarization, and PACER downloads
FROM python:3.12-slim

# Install system dependencies for OCR
RUN apt-get update && apt-get install -y --no-install-recommends \
    tesseract-ocr \
    tesseract-ocr-eng \
    poppler-utils \
    libgl1 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy worker code
COPY *.py .

# Health check - verify tesseract and python imports work
RUN python -c "import pytesseract; import google.generativeai; import psycopg2; print('OK')"

CMD ["python", "worker.py"]
