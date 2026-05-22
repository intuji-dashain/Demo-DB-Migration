FROM python:3.11-slim

WORKDIR /app

# Install build dependencies for database adapters
RUN apt-get update && apt-get install -y \
    gcc \
    g++ \
    && rm -rf /var/lib/apt/lists/*

# Install production-grade dependencies
RUN pip install --no-cache-dir \
    pandas \
    sqlalchemy \
    pymssql \
    psycopg2-binary \
    uuid6 \
    tenacity

# Copy all migration files
COPY config.py .
COPY migration_tracker.py .
COPY migrate.py .
COPY seed.py .

# Run migration by default
CMD ["python", "migrate.py"]