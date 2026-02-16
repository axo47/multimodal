FROM python:3.10-slim

WORKDIR /app

# Copier requirements
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copier les fichiers Python (serveur)
COPY server.py .

# Copier les fichiers frontend OBLIGATOIRES
COPY index.html .
COPY app.js .

# Images (si tu en as)
# Décommente si tu as une image background:
COPY background.png .

# Exposer le port
EXPOSE 8080

# Lancer le serveur
CMD ["uvicorn", "server:app", "--host", "0.0.0.0", "--port", "8080"]
