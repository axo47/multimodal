#!/bin/bash

# ============================================================================
# Setup Script COMPLET - Multimodal RAG INF1900
# Déploie: Backend + Frontend en une seule commande
# Usage: ./setup.sh
# ============================================================================

set -e  # Exit on error

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
PURPLE='\033[0;35m'
NC='\033[0m'

echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║   🚀 Multimodal RAG INF1900 - Déploiement Complet           ║"
echo "║   Backend + Frontend en une seule commande                 ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# ============================================================================
# 1. VÉRIFICATIONS
# ============================================================================

echo -e "${BLUE}📋 Vérification des prérequis...${NC}"

if ! command -v gcloud &> /dev/null; then
    echo -e "${RED}❌ gcloud CLI manquant${NC}"
    echo "Installez-le: brew install google-cloud-sdk"
    exit 1
fi
echo -e "${GREEN}✅ gcloud CLI${NC}"

if ! command -v python3 &> /dev/null; then
    echo -e "${RED}❌ Python 3 manquant${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Python 3${NC}"

# ============================================================================
# 2. CONFIGURATION PROJET
# ============================================================================

echo ""
echo -e "${BLUE}☁️  Configuration Google Cloud...${NC}"
echo ""
echo "Créez votre projet sur:"
echo "  👉 https://console.cloud.google.com/projectcreate"
echo ""

read -p "Project ID: " PROJECT_ID

if [ -z "$PROJECT_ID" ]; then
    echo -e "${RED}❌ Project ID requis${NC}"
    exit 1
fi

echo -e "${BLUE}🔍 Vérification du projet...${NC}"
if ! gcloud projects describe $PROJECT_ID &>/dev/null; then
    echo -e "${RED}❌ Projet inexistant ou inaccessible${NC}"
    exit 1
fi

gcloud config set project $PROJECT_ID
echo -e "${GREEN}✅ Projet: $PROJECT_ID${NC}"

# ============================================================================
# 3. ACTIVATION APIs
# ============================================================================

echo ""
echo -e "${BLUE}⚙️  Activation des APIs...${NC}"

APIS=(
    "run.googleapis.com"
    "cloudbuild.googleapis.com"
    "aiplatform.googleapis.com"
    "secretmanager.googleapis.com"
)

for api in "${APIS[@]}"; do
    echo "  - $api"
    gcloud services enable $api --project=$PROJECT_ID --quiet
done

echo -e "${GREEN}✅ APIs activées${NC}"

# ============================================================================
# 4. CLÉ GEMINI
# ============================================================================

echo ""
echo -e "${BLUE}🔑 Configuration Gemini...${NC}"
echo ""
echo "Obtenez votre clé: https://aistudio.google.com/apikey"
echo ""
read -p "Clé API Gemini: " GEMINI_KEY

if [ -z "$GEMINI_KEY" ]; then
    echo -e "${RED}❌ Clé requise${NC}"
    exit 1
fi

echo "📦 Sauvegarde dans Secret Manager..."
echo -n "$GEMINI_KEY" | gcloud secrets create gemini-api-key \
    --data-file=- \
    --project=$PROJECT_ID 2>/dev/null || \
    echo -n "$GEMINI_KEY" | gcloud secrets versions add gemini-api-key \
    --data-file=- \
    --project=$PROJECT_ID

echo -e "${GREEN}✅ Clé sauvegardée${NC}"

# ============================================================================
# 5. INGESTION (OPTIONNEL)
# ============================================================================

echo ""
echo -e "${BLUE}📚 Ingestion de la base de connaissances...${NC}"
read -p "Ingérer maintenant? (o/N): " DO_INGEST

if [[ "$DO_INGEST" =~ ^[Oo]$ ]]; then
    echo "⚙️  Configuration Python..."
    
    # Vérifier Python 3.12
    if command -v python3.12 &> /dev/null; then
        PYTHON_CMD="python3.12"
    else
        PYTHON_CMD="python3"
    fi
    
    $PYTHON_CMD -m venv venv
    source venv/bin/activate
    pip install --upgrade pip --quiet
    pip install -r backend/requirements.txt --quiet
    
    echo "🚀 Ingestion (5-10 min)..."
    export GOOGLE_API_KEY=$GEMINI_KEY
    python backend/ingest.py
    
    deactivate
    rm -rf venv
    
    echo -e "${GREEN}✅ Ingestion terminée${NC}"
else
    echo "⏭️  Ingestion ignorée"
fi

# ============================================================================
# 6. DÉPLOIEMENT BACKEND
# ============================================================================

echo ""
echo -e "${PURPLE}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${PURPLE}║         🔧 DÉPLOIEMENT BACKEND                       ║${NC}"
echo -e "${PURPLE}╚══════════════════════════════════════════════════════╝${NC}"
echo ""

echo -e "${BLUE}🏗️  Build et déploiement du backend...${NC}"
gcloud builds submit --config cloudbuild.yaml --project=$PROJECT_ID

echo ""
echo -e "${BLUE}🔍 Récupération URL backend...${NC}"
BACKEND_URL=$(gcloud run services describe multimodal-rag-inf1900 \
    --region=us-central1 \
    --project=$PROJECT_ID \
    --format='value(status.url)' 2>/dev/null)

if [ -z "$BACKEND_URL" ]; then
    echo -e "${RED}❌ Impossible de récupérer l'URL du backend${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Backend déployé: $BACKEND_URL${NC}"

# ============================================================================
# 7. DÉPLOIEMENT FRONTEND
# ============================================================================

echo ""
echo -e "${PURPLE}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${PURPLE}║         🎨 DÉPLOIEMENT FRONTEND                      ║${NC}"
echo -e "${PURPLE}╚══════════════════════════════════════════════════════╝${NC}"
echo ""

echo -e "${BLUE}🏗️  Build et déploiement du frontend...${NC}"
gcloud builds submit --config cloudbuild_frontend.yaml --project=$PROJECT_ID

echo ""
echo -e "${BLUE}🔗 Configuration de la connexion Frontend → Backend...${NC}"
gcloud run services update rag-frontend \
    --region=us-central1 \
    --set-env-vars=BACKEND_URL=$BACKEND_URL \
    --project=$PROJECT_ID \
    --quiet

echo ""
echo -e "${BLUE}🌐 Autorisation des accès publics...${NC}"
gcloud run services add-iam-policy-binding rag-frontend \
    --region=us-central1 \
    --member="allUsers" \
    --role="roles/run.invoker" \
    --project=$PROJECT_ID \
    --quiet

echo ""
echo -e "${BLUE}🔍 Récupération URL frontend...${NC}"
FRONTEND_URL=$(gcloud run services describe rag-frontend \
    --region=us-central1 \
    --project=$PROJECT_ID \
    --format='value(status.url)' 2>/dev/null)

if [ -z "$FRONTEND_URL" ]; then
    echo -e "${RED}❌ Impossible de récupérer l'URL du frontend${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Frontend déployé: $FRONTEND_URL${NC}"

# ============================================================================
# 8. RÉSUMÉ FINAL
# ============================================================================

echo ""
echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║              🎉 DÉPLOIEMENT COMPLET RÉUSSI! 🎉             ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo -e "${GREEN}📊 Architecture Déployée:${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo -e "${BLUE}🎨 FRONTEND (Interface Utilisateur)${NC}"
echo "   URL:     $FRONTEND_URL"
echo "   Service: rag-frontend"
echo "   Stack:   HTML/JS + FastAPI"
echo ""
echo -e "${BLUE}🔧 BACKEND (API Multimodale)${NC}"
echo "   URL:     $BACKEND_URL"
echo "   Service: multimodal-rag-inf1900"
echo "   Stack:   FastAPI + Gemini + ChromaDB"
echo ""
echo -e "${BLUE}☁️  PROJET GOOGLE CLOUD${NC}"
echo "   ID:      $PROJECT_ID"
echo "   Région:  us-central1"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo -e "${GREEN}🌐 VOTRE APPLICATION EST LIVE:${NC}"
echo ""
echo -e "${YELLOW}   👉 $FRONTEND_URL ${NC}"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo -e "${GREEN}✅ Fonctionnalités Disponibles:${NC}"
echo ""
echo "   📝 Texte:   Tapez vos questions"
echo "   📷 Images:  Upload pour OCR + analyse"
echo "   🎤 Vocal:   Conversation temps réel"
echo "   📚 RAG:     Documentation INF1900 intégrée"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo -e "${YELLOW}📝 Commandes Utiles:${NC}"
echo ""
echo "  Logs Backend:"
echo "    gcloud run logs tail multimodal-rag-inf1900 --project=$PROJECT_ID"
echo ""
echo "  Logs Frontend:"
echo "    gcloud run logs tail rag-frontend --project=$PROJECT_ID"
echo ""
echo "  Dashboard Cloud Run:"
echo "    https://console.cloud.google.com/run?project=$PROJECT_ID"
echo ""
echo "  Redéployer Backend:"
echo "    gcloud builds submit --config cloudbuild.yaml --project=$PROJECT_ID"
echo ""
echo "  Redéployer Frontend:"
echo "    gcloud builds submit --config cloudbuild_frontend.yaml --project=$PROJECT_ID"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo -e "${GREEN}🎯 Prochaines Étapes:${NC}"
echo ""
echo "  1. Ouvrez: $FRONTEND_URL"
echo "  2. Autorisez le microphone (Chrome recommandé)"
echo "  3. Testez les 3 modes:"
echo "     - Tapez une question"
echo "     - Uploadez une image de circuit"
echo "     - Parlez avec l'assistant"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo -e "${PURPLE}🎉 Bon apprentissage avec votre assistant multimodal INF1900! 🎉${NC}"
echo ""