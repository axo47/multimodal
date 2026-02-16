"""
Frontend Server - Sert l'interface utilisateur
Configuré pour servir les fichiers statiques (HTML, JS, images)
"""

from fastapi import FastAPI
from fastapi.responses import FileResponse, JSONResponse
from fastapi.middleware.cors import CORSMiddleware
import os

app = FastAPI()

# CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# URL du backend (sera configuré via variable d'environnement)
BACKEND_URL = os.getenv("BACKEND_URL", "http://localhost:8080")

@app.get("/config")
async def config():
    """Retourne la configuration pour le frontend"""
    return JSONResponse({
        "backend_url": BACKEND_URL
    })

@app.get("/")
async def index():
    """Page d'accueil"""
    return FileResponse("index.html")

@app.get("/app.js")
async def app_js():
    """Fichier JavaScript"""
    return FileResponse("app.js")

@app.get("/background.png")
async def background_png():
    """Image de background"""
    if os.path.exists("background.png"):
        return FileResponse("background.png")
    return JSONResponse({"error": "Image not found"}, status_code=404)

@app.get("/{filename}")
async def serve_static(filename: str):
    """
    Servir n'importe quel fichier statique
    Gère: .html, .js, .css, .png, .jpg, etc.
    """
    
    # Liste des extensions autorisées
    allowed_extensions = [
        '.html', '.htm',
        '.js', 
        '.css',
        '.png', '.jpg', '.jpeg', '.gif', '.webp', '.svg',
        '.ico'
    ]
    
    # Vérifier l'extension
    _, ext = os.path.splitext(filename)
    if ext.lower() not in allowed_extensions:
        return JSONResponse(
            {"error": f"File type not allowed: {ext}"}, 
            status_code=403
        )
    
    # Vérifier que le fichier existe
    if not os.path.exists(filename):
        return JSONResponse(
            {"error": f"File not found: {filename}"}, 
            status_code=404
        )
    
    # Servir le fichier
    return FileResponse(filename)

@app.get("/health")
async def health():
    """Health check"""
    return {"status": "healthy", "service": "rag-frontend"}

if __name__ == "__main__":
    import uvicorn
    port = int(os.getenv("PORT", 8080))
    uvicorn.run(app, host="0.0.0.0", port=port)