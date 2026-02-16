"""
Script d'ingestion pour créer la base de connaissances RAG
Compatible avec ChromaDB local ET Vertex AI Vector Search
"""

import os
import sys
from urllib.parse import urljoin
import requests
from bs4 import BeautifulSoup

from langchain_community.document_loaders import RecursiveUrlLoader, PyPDFLoader
from langchain_google_genai import GoogleGenerativeAIEmbeddings
from langchain_text_splitters import RecursiveCharacterTextSplitter
from langchain_chroma import Chroma

# ============================================================================
# CONFIGURATION
# ============================================================================

ENTRY_URL = "https://cours.polymtl.ca/inf1900/"
DB_PATH = "./inf1900_db"
USE_CLOUD = os.getenv("USE_VERTEX_AI", "false").lower() == "true"

# ============================================================================
# HELPERS
# ============================================================================

def caption_image(img_url):
    """
    Génère une description pour une image.
    En production, utiliser Gemini Vision pour une vraie caption.
    """
    return f"[Image: {img_url}]"

def process_pdf(pdf_url):
    """Télécharge et extrait le texte d'un PDF"""
    try:
        print(f"    📄 Processing PDF: {pdf_url}")
        loader = PyPDFLoader(pdf_url)
        pages = loader.load()
        full_text = "\n".join([p.page_content for p in pages])
        return f"\n--- START PDF ({pdf_url}) ---\n{full_text}\n--- END PDF ---\n"
    except Exception as e:
        print(f"    ❌ Failed to process PDF {pdf_url}: {e}")
        return ""

def enrich_document(doc):
    """
    Enrichit un document HTML avec le contenu des PDFs liés
    """
    url = doc.metadata['source']
    soup = BeautifulSoup(doc.page_content, "html.parser")
    
    print(f"🔗 Enriching page: {url}")

    # 1. Extraire le texte principal
    text_content = soup.get_text(separator="\n", strip=True)
    
    # 2. Trouver et traiter les PDFs internes
    pdf_contents = []
    for link in soup.find_all('a', href=True):
        full_link = urljoin(url, link['href'])
        
        if link['href'].lower().endswith('.pdf') and "cours.polymtl.ca" in full_link:
            pdf_text = process_pdf(full_link)
            pdf_contents.append(pdf_text)

    # 3. Trouver et taguer les images
    img_captions = []
    for img in soup.find_all('img', src=True):
        full_src = urljoin(url, img['src'])
        if "icon" not in img['src'].lower():
            img_captions.append(caption_image(full_src))

    # 4. Mettre à jour le document
    doc.page_content = text_content + "\n".join(pdf_contents) + "\n".join(img_captions)
    return doc

# ============================================================================
# INGESTION LOCALE (ChromaDB)
# ============================================================================

def ingest_local():
    """Ingestion vers ChromaDB local"""
    print(f"🚀 Starting crawl of {ENTRY_URL}...")
    
    # 1. Charger les pages HTML brutes
    loader = RecursiveUrlLoader(
        url=ENTRY_URL,
        max_depth=3,
        extractor=lambda x: x,
        prevent_outside=True 
    )
    raw_docs = loader.load()
    print(f"✅ Found {len(raw_docs)} raw pages.")

    # 2. Enrichir les documents
    print("⚙️  Enriching documents...")
    enriched_docs = []
    for doc in raw_docs:
        try:
            enriched_docs.append(enrich_document(doc))
        except Exception as e:
            print(f"Skipped {doc.metadata['source']}: {e}")

    # 3. Découper le texte
    text_splitter = RecursiveCharacterTextSplitter(
        chunk_size=2000,
        chunk_overlap=200
    )
    splits = text_splitter.split_documents(enriched_docs)
    print(f"✂️  Split into {len(splits)} chunks.")

    # 4. Vectoriser et sauvegarder (ChromaDB)
    print("🧠 Vectorizing with Gemini Embeddings...")
    embeddings = GoogleGenerativeAIEmbeddings(
        model="gemini-embedding-001"
    )
    
    Chroma.from_documents(
        documents=splits,
        embedding=embeddings,
        persist_directory=DB_PATH
    )
    print(f"🎉 Success! Database saved to {DB_PATH}")

# ============================================================================
# INGESTION CLOUD (Vertex AI Vector Search)
# ============================================================================

def ingest_cloud():
    """
    Ingestion vers Vertex AI Vector Search
    Pour la production sur Google Cloud
    """
    print("☁️  Cloud ingestion (Vertex AI) - Coming soon!")
    print("For now, using local ChromaDB")
    
    # TODO: Implémenter Vertex AI Vector Search
    # from google.cloud import aiplatform
    # from langchain_google_vertexai import VertexAIEmbeddings
    # 
    # aiplatform.init(
    #     project=os.getenv("GOOGLE_CLOUD_PROJECT"),
    #     location=os.getenv("GOOGLE_CLOUD_LOCATION", "us-central1")
    # )
    # 
    # embeddings = VertexAIEmbeddings(model_name="text-embedding-004")
    # 
    # # Create Vector Search Index
    # index = aiplatform.MatchingEngineIndex.create_tree_ah_index(...)
    
    # Pour l'instant, utiliser ChromaDB
    ingest_local()

# ============================================================================
# MAIN
# ============================================================================

def main():
    """Point d'entrée principal"""
    print("=" * 60)
    print("📚 INF1900 RAG Knowledge Base Ingestion")
    print("=" * 60)
    print(f"Target: {ENTRY_URL}")
    print(f"Mode: {'Cloud (Vertex AI)' if USE_CLOUD else 'Local (ChromaDB)'}")
    print("=" * 60)
    
    if USE_CLOUD:
        ingest_cloud()
    else:
        ingest_local()
    
    print("\n✅ Ingestion complete!")
    print(f"📊 Database location: {DB_PATH}")
    print("\n🚀 Next steps:")
    print("1. Set GEMINI_API_KEY environment variable")
    print("2. Run: python backend/main.py")
    print("3. Or deploy to Cloud Run!")

if __name__ == "__main__":
    main()
