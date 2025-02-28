FROM python:3.9-slim

WORKDIR /app

RUN pip install --no-cache-dir fastapi uvicorn

COPY hello.py .

EXPOSE 8000

CMD ["uvicorn","hello:app","--host","0.0.0.0","--port","8000"]
