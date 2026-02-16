"""
🚀 Multimodal RAG INF1900 - AUDIO SIMPLE (pas de WebSocket!)
- Texte: RAG direct
- Images Upload: RAG enrichit
- Images Génération: RAG enrichit  
- Audio Upload: Transcrit + RAG + Répond (SIMPLE!)
"""

import os
import base64
from typing import Optional
from fastapi import FastAPI, HTTPException, UploadFile, File
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from google import genai
from google.genai.types import Part
from langchain_google_genai import GoogleGenerativeAIEmbeddings
from langchain_chroma import Chroma
import tempfile

# Vertex AI
try:
    from vertexai.preview.vision_models import ImageGenerationModel
    import vertexai
    IMAGEN_AVAILABLE = True
except ImportError:
    IMAGEN_AVAILABLE = False

# ============================================================================
# CONFIGURATION
# ============================================================================

app = FastAPI(title="Multimodal RAG INF1900", version="7.0-AUDIO-SIMPLE")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

DB_PATH = os.getenv("CHROMA_DB_PATH", "./inf1900_db")
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")
PROJECT_ID = os.getenv("GCP_PROJECT_ID", "engaged-card-487404-k3")

# Modèles
TEXT_MODEL = "gemini-2.5-flash"  # Pour tout (texte, image, audio)

if IMAGEN_AVAILABLE:
    try:
        vertexai.init(project=PROJECT_ID, location="us-central1")
    except Exception as e:
        IMAGEN_AVAILABLE = False

# ============================================================================
# MODELS
# ============================================================================

class QueryRequest(BaseModel):
    query: str

class ImageUploadRequest(BaseModel):
    image: str
    mimeType: str = "image/jpeg"
    query: Optional[str] = None

class AudioUploadRequest(BaseModel):
    audio: str  # base64
    mimeType: str = "audio/webm"  # ou audio/mp3, audio/wav

class ImageGenerationRequest(BaseModel):
    prompt: str
    number_of_images: int = 1

# ============================================================================
# RAG ENGINE
# ============================================================================

class RAGEngine:
    def __init__(self, db_path: str):
        self.db_path = db_path
        self.vector_db = None
        self.embeddings = None
        self._initialize()
    
    def _initialize(self):
        if not os.path.exists(self.db_path):
            print(f"⚠️  Database not found at {self.db_path}")
            return
        
        try:
            self.embeddings = GoogleGenerativeAIEmbeddings(model="text-embedding-004")
            self.vector_db = Chroma(
                persist_directory=self.db_path,
                embedding_function=self.embeddings
            )
            print(f"✅ RAG Engine initialized")
        except Exception as e:
            print(f"❌ RAG init error: {e}")
    
    def get_context(self, query: str, k: int = 3) -> str:
        if not self.vector_db:
            return ""
        
        try:
            docs = self.vector_db.similarity_search(query, k=k)
            if not docs:
                return ""
            
            context_parts = []
            for i, doc in enumerate(docs, 1):
                source = doc.metadata.get('source', 'Unknown')
                content = doc.page_content[:800]
                context_parts.append(f"[Doc {i} - {source}]\n{content}\n")
            
            return "\n---\n".join(context_parts)
        except Exception as e:
            print(f"Search error: {e}")
            return ""

rag_engine = RAGEngine(DB_PATH)

# ============================================================================
# GEMINI CLIENT
# ============================================================================

### TO DO METTRE LA VALEUR DE L'API-KEY de gemini (decommenter la ligne dessous)
# client

TA_INSTRUCTION = """Tu es un TA expert pour INF1900 à Polytechnique Montréal.
Réponds de manière pédagogique et concise.
Cite tes sources si disponibles."""

# ============================================================================
# ENDPOINTS
# ============================================================================

@app.get("/")
async def root():
    return {
        "status": "🚀 Multimodal RAG INF1900 v7.0-AUDIO-SIMPLE",
        "features": {
            "text": "Questions/réponses avec RAG",
            "images_upload": "OCR + Analyse enrichie",
            "images_generate": "Génération enrichie",
            "audio_upload": "🎤 Transcription + RAG (SIMPLE, pas de WebSocket!)",
        }
    }

@app.get("/health")
async def health():
    return {
        "status": "healthy",
        "rag": "ok" if rag_engine.vector_db else "unavailable",
        "gemini": "ok" if client else "unavailable",
        "imagen": "ok" if IMAGEN_AVAILABLE else "unavailable"
    }

@app.post("/query")
async def query_text(request: QueryRequest):
    if not client:
        raise HTTPException(503, "Gemini not configured")
    
    query = request.query
    
    ### TO DO Definir le contxte 
    # context 
    if context:
        prompt = f"""📚 Documentation INF1900:
{context}

❓ Question: {query}

Réponds en utilisant la doc."""
    else:
        prompt = f"""❓ Question INF1900: {query}

Réponds de manière pédagogique."""
    
    try:
        response = client.models.generate_content(
            model=TEXT_MODEL,
            contents=prompt,
            config={
                "system_instruction": TA_INSTRUCTION,
                "temperature": 0.7,
                "max_output_tokens": 1500
            }
        )
        
        return {
            "query": query,
            "answer": response.text,
            "has_context": bool(context),
            "rag_used": "✅ RAG utilisé" if context else "⚠️ Pas de contexte"
        }
    except Exception as e:
        print(f"Error: {e}")
        raise HTTPException(500, str(e))

@app.post("/upload-image")
async def upload_image(request: ImageUploadRequest):
    if not client:
        raise HTTPException(503, "Gemini not configured")
    
    try:
        image_data = base64.b64decode(request.image)
        
        initial_prompt = """Analyse rapidement:
- Circuit: composants
- Code: langage
- Texte: OCR
- Schéma: description

Bref (2-3 phrases)."""
        
        initial_response = client.models.generate_content(
            model=TEXT_MODEL,
            contents=[
                initial_prompt,
                Part.from_bytes(data=image_data, mime_type=request.mimeType)
            ],
            config={"temperature": 0.3}
        )
        
        initial_analysis = initial_response.text
        rag_query = request.query if request.query else initial_analysis
        context = rag_engine.get_context(rag_query, k=3)
        
        if context:
            final_prompt = f"""📚 Documentation:
{context}

📷 Analyse: {initial_analysis}

❓ Question: {request.query if request.query else "Explique"}

Combine analyse + doc."""
        else:
            final_prompt = f"""📷 Analyse: {initial_analysis}

❓ Question: {request.query if request.query else "Explique"}

Analyse pédagogique."""
        
        final_response = client.models.generate_content(
            model=TEXT_MODEL,
            contents=[
                final_prompt,
                Part.from_bytes(data=image_data, mime_type=request.mimeType)
            ],
            config={
                "system_instruction": TA_INSTRUCTION,
                "temperature": 0.5
            }
        )
        
        return {
            "response": final_response.text,
            "rag_used": "✅ RAG utilisé" if context else "⚠️ Pas de doc",
            "has_context": bool(context)
        }
        
    except Exception as e:
        print(f"Image error: {e}")
        raise HTTPException(500, str(e))

@app.post("/upload-audio")
async def upload_audio(request: AudioUploadRequest):
    """
    🎤 NOUVEAU: Upload Audio Simple
    1. Reçoit audio en base64
    2. Transcrit avec Gemini
    3. Cherche dans RAG
    4. Répond
    """
    if not client:
        raise HTTPException(503, "Gemini not configured")
    
    try:
        # Décoder l'audio
        ### TO DO definir audio_data
        # audio_data
        
        # Étape 1: Transcription
        print("🎤 Transcription de l'audio...")
        transcription_response = client.models.generate_content(
            model=TEXT_MODEL,
            contents=[
                "Transcris cet audio en français. Retourne UNIQUEMENT le texte transcrit, rien d'autre.",
                Part.from_bytes(data=audio_data, mime_type=request.mimeType)
            ],
            config={"temperature": 0.1}
        )
        
        transcription = transcription_response.text.strip()
        print(f"📝 Transcription: {transcription}")
        
        # Étape 2: RAG - Chercher dans la doc
        # definir contexte
        context 
        
        # Étape 3: Générer réponse enrichie
        if context:
            answer_prompt = f"""📚 Documentation INF1900:
{context}

❓ Question de l'étudiant: {transcription}

Réponds en utilisant la doc."""
        else:
            answer_prompt = f"""❓ Question INF1900: {transcription}

Réponds de manière pédagogique."""
        
        answer_response = client.models.generate_content(
            model=TEXT_MODEL,
            contents=answer_prompt,
            config={
                "system_instruction": TA_INSTRUCTION,
                "temperature": 0.7,
                "max_output_tokens": 1000
            }
        )
        
        return {
            "transcription": transcription,
            "answer": answer_response.text,
            "has_context": bool(context),
            "rag_used": "✅ RAG utilisé" if context else "⚠️ Pas de doc"
        }
        
    except Exception as e:
        print(f"Audio error: {e}")
        raise HTTPException(500, str(e))

@app.post("/generate-image")
async def generate_image(request: ImageGenerationRequest):
    if not IMAGEN_AVAILABLE:
        raise HTTPException(503, "Imagen non disponible")
    
    try:
        context = rag_engine.get_context(request.prompt, k=3)
        
        if context:
            enhanced_prompt = f"""Technical INF1900 diagram:
{request.prompt}

Specs:
{context[:500]}

Style: Educational, clear."""
        else:
            enhanced_prompt = f"""Technical INF1900 diagram:
{request.prompt}

Style: Educational."""
            
        # TO DO : Definir le modele     
        # model
        
        images = model.generate_images(
            prompt=enhanced_prompt,
            number_of_images=request.number_of_images,
            aspect_ratio="1:1",
            safety_filter_level="block_some",
            person_generation="allow_adult"
        )
        
        image_bytes = images[0]._image_bytes
        image_b64 = base64.b64encode(image_bytes).decode('utf-8')
        
        return {
            "success": True,
            "image": image_b64,
            "mimeType": "image/png",
            "prompt": request.prompt,
            "rag_used": "✅" if context else "⚠️",
            "enhanced": bool(context)
        }
    
    except Exception as e:
        print(f"Image generation error: {e}")
        raise HTTPException(500, str(e))

# ============================================================================
# STARTUP
# ============================================================================

@app.on_event("startup")
async def startup():
    print("=" * 70)
    print("🚀 Multimodal RAG INF1900 v7.0-AUDIO-SIMPLE")
    print("=" * 70)
    print(f"📚 RAG: {'✅' if rag_engine.vector_db else '❌'}")
    print(f"🤖 Gemini: {'✅' if client else '❌'}")
    print(f"🎨 Imagen: {'✅' if IMAGEN_AVAILABLE else '❌'}")
    print(f"")
    print(f"🔥 MODES:")
    print(f"   ✅ Texte + RAG")
    print(f"   ✅ Upload Images + RAG")
    print(f"   ✅ Génération Images + RAG")
    print(f"   ✅ 🎤 Upload Audio + RAG (SIMPLE!)")
    print("=" * 70)

if __name__ == "__main__":
    import uvicorn
    port = int(os.getenv("PORT", 8080))
    uvicorn.run(app, host="0.0.0.0", port=port)