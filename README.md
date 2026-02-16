# 🚀 Multimodal RAG Assistant - INF1900

Assistant intelligent multimodal avec RAG (Retrieval-Augmented Generation) pour le cours INF1900 à Polytechnique Montréal.

![Version](https://img.shields.io/badge/version-7.0-blue)
![Python](https://img.shields.io/badge/python-3.10+-green)
![License](https://img.shields.io/badge/license-MIT-orange)

---

## 📋 Table des Matières

- [Vue d'ensemble](#-vue-densemble)
- [Architecture](#-architecture)
- [Fonctionnalités](#-fonctionnalités)
- [Prérequis](#-prérequis)
- [Installation](#-installation)
  - [Linux](#-linux)
  - [macOS](#-macos)
  - [Windows](#-windows)
- [Utilisation](#-utilisation)
- [Comment ça marche](#-comment-ça-marche)
- [Structure du projet](#-structure-du-projet)
- [Technologies](#-technologies)
- [Développement](#-développement)
- [Dépannage](#-dépannage)
- [Contribuer](#-contribuer)

---

## 🎯 Vue d'ensemble

Cet assistant RAG multimodal permet aux étudiants d'INF1900 d'interagir avec la documentation du cours via **4 modes différents**:

- 📝 **Texte**: Questions/réponses enrichies par RAG
- 📷 **Images**: Upload et analyse avec Vision AI + RAG
- 🎵 **Audio**: Upload de fichiers audio pour transcription + RAG
- 🎨 **Génération**: Création d'images techniques avec prompts enrichis par RAG

**Caractéristique unique**: Tous les modes utilisent le RAG pour enrichir les réponses avec la documentation officielle du cours.

---

## 🏗️ Architecture

### Vue d'ensemble de l'architecture

```
┌─────────────────────────────────────────────────────────────┐
│                         UTILISATEUR                         │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────┐
│                    FRONTEND (Cloud Run)                     │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  Interface Web (HTML/JS)                             │   │
│  │  • Upload fichiers (images, audio)                   │   │
│  │  • Affichage conversations                           │   │
│  │  • Gestion états UI                                  │   │
│  └────────────┬─────────────────────────────────────────┘   │
│               │ HTTPS                                        │
│               │ REST API                                     │
└───────────────┼──────────────────────────────────────────────┘
                │
                ▼
┌─────────────────────────────────────────────────────────────┐
│                    BACKEND (Cloud Run)                      │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  FastAPI Server                                      │   │
│  │  • Endpoints REST (/query, /upload-image, etc.)     │   │
│  │  • Orchestration des services                       │   │
│  └────┬─────────────┬─────────────┬─────────────────────┘   │
│       │             │             │                          │
│       ▼             ▼             ▼                          │
│  ┌────────┐   ┌─────────┐   ┌──────────┐                   │
│  │  RAG   │   │ Gemini  │   │  Imagen  │                   │
│  │ Engine │   │   API   │   │   API    │                   │
│  └────────┘   └─────────┘   └──────────┘                   │
│       │                                                      │
│       ▼                                                      │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  ChromaDB (Vector Database)                         │   │
│  │  • Embeddings de la documentation INF1900           │   │
│  │  • Recherche sémantique                             │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────┐
│              SERVICES GOOGLE CLOUD                          │
│  • Cloud Run (hosting)                                      │
│  • Cloud Build (CI/CD)                                      │
│  • Secret Manager (clés API)                                │
│  • Vertex AI (Imagen)                                       │
└─────────────────────────────────────────────────────────────┘
```

---

### Architecture Client-Serveur Détaillée

#### 🎨 Frontend (Client)

**Technologie**: HTML5 + JavaScript Vanilla + FastAPI (serveur statique)

**Responsabilités**:
1. **Interface utilisateur**:
   - Affichage du chat
   - Gestion des inputs (texte, fichiers)
   - Prévisualisation des résultats

2. **Communication avec le backend**:
   - Appels REST API via `fetch()`
   - Envoi de fichiers en base64
   - Réception et affichage des réponses

3. **Gestion d'état**:
   - Historique de conversation
   - État des uploads
   - Badges RAG (indique si le RAG a été utilisé)

**Hébergement**: Cloud Run (container Docker)

**Fichiers clés**:
- `index.html`: Interface utilisateur
- `app.js`: Logique frontend
- `server.py`: Serveur FastAPI qui sert les fichiers statiques

---

#### 🔧 Backend (Serveur)

**Technologie**: FastAPI + Python 3.10+

**Responsabilités**:
1. **API REST**:
   - `/query`: Questions texte
   - `/upload-image`: Analyse d'images
   - `/upload-audio`: Transcription audio
   - `/generate-image`: Génération d'images

2. **Orchestration des services**:
   - Coordination RAG → Gemini → Réponse
   - Gestion des embeddings et recherche vectorielle
   - Intégration Vertex AI pour Imagen

3. **RAG Engine**:
   - Chargement de ChromaDB
   - Recherche sémantique (k=3 à 5 documents)
   - Enrichissement des prompts

**Hébergement**: Cloud Run (container Docker)

**Fichiers clés**:
- `main.py`: Serveur FastAPI + endpoints
- `ingest.py`: Ingestion de la documentation dans ChromaDB
- `requirements.txt`: Dépendances Python

---

### Flux de Données Multimodal

#### 📝 Mode Texte
```
Utilisateur tape question
    ↓
Frontend: POST /query {"query": "..."}
    ↓
Backend:
    1. Reçoit question
    2. RAG: Cherche dans ChromaDB (k=5)
    3. Gemini: Génère réponse avec contexte RAG
    ↓
Frontend: Affiche réponse + badge RAG
```

#### 📷 Mode Image
```
Utilisateur upload image
    ↓
Frontend: Convertit en base64 → POST /upload-image
    ↓
Backend:
    1. Reçoit image base64
    2. Gemini Vision: Analyse initiale
    3. RAG: Cherche contexte basé sur l'analyse
    4. Gemini: Combine Vision + RAG → Réponse enrichie
    ↓
Frontend: Affiche analyse + badge RAG
```

#### 🎵 Mode Audio
```
Utilisateur upload fichier audio
    ↓
Frontend: Convertit en base64 → POST /upload-audio
    ↓
Backend:
    1. Reçoit audio base64
    2. Gemini: Transcrit l'audio
    3. RAG: Cherche contexte basé sur transcription
    4. Gemini: Génère réponse avec contexte RAG
    ↓
Frontend: Affiche transcription + réponse + badge RAG
```

#### 🎨 Mode Génération
```
Utilisateur entre prompt
    ↓
Frontend: POST /generate-image {"prompt": "..."}
    ↓
Backend:
    1. Reçoit prompt
    2. RAG: Cherche spécifications techniques
    3. Enrichit prompt avec contexte RAG
    4. Vertex AI Imagen: Génère image
    ↓
Frontend: Affiche image + badge RAG
```

---

## ✨ Fonctionnalités

### 1. RAG (Retrieval-Augmented Generation)

**Qu'est-ce que le RAG ?**

Le RAG combine:
- **Retrieval**: Recherche sémantique dans une base de connaissances
- **Generation**: Génération de réponses par un LLM

**Comment ça marche ici ?**

1. **Ingestion** (une seule fois):
   ```
   Documentation INF1900
       ↓
   Découpage en chunks (~800 caractères)
       ↓
   Génération d'embeddings (text-embedding-004)
       ↓
   Stockage dans ChromaDB
   ```

2. **Requête** (à chaque question):
   ```
   Question utilisateur
       ↓
   Génération embedding de la question
       ↓
   Recherche similarité cosinus dans ChromaDB
       ↓
   Récupération top-k documents (k=3 à 5)
       ↓
   Injection dans le prompt Gemini
       ↓
   Réponse enrichie
   ```

**Avantages**:
- ✅ Réponses basées sur la doc officielle
- ✅ Pas d'hallucinations sur le contenu du cours
- ✅ Citations des sources
- ✅ Toujours à jour (selon la doc ingérée)

---

### 2. Multimodal

**4 modes d'interaction, tous enrichis par RAG:**

| Mode | Input | Processing | RAG | Output |
|------|-------|------------|-----|--------|
| **Texte** | Question tapée | Gemini 2.5 Flash | ✅ Cherche dans doc | Réponse enrichie |
| **Image** | Upload image | Gemini Vision → Analyse | ✅ Cherche contexte | Analyse + explications |
| **Audio** | Upload MP3/WAV | Gemini → Transcription | ✅ Cherche dans doc | Transcription + réponse |
| **Génération** | Prompt texte | RAG → Prompt enrichi | ✅ Ajoute specs techniques | Image générée |

**Tous les modes utilisent le RAG !** C'est la force de cette architecture.

---

### 3. Intégrations API

#### Gemini API (Google AI Studio)
- **Modèle**: `gemini-2.5-flash`
- **Usages**:
  - Génération de réponses texte
  - Analyse d'images (Vision)
  - Transcription audio
- **Configuration**: Clé API dans Secret Manager

#### Vertex AI (Imagen)
- **Modèle**: `imagen-3.0-generate-002`
- **Usage**: Génération d'images techniques
- **Configuration**: Service account GCP

#### ChromaDB
- **Type**: Vector database
- **Stockage**: Filesystem (`/inf1900_db`)
- **Embeddings**: `text-embedding-004` (Google)

---

## 📋 Prérequis

### Obligatoire

- **Compte Google Cloud**
  - Carte de crédit requise (crédits gratuits $300)
  - Créer un projet: [console.cloud.google.com](https://console.cloud.google.com)

- **Google Cloud SDK** (gcloud CLI)
  - [Instructions d'installation](https://cloud.google.com/sdk/docs/install)
  - Authentification: `gcloud auth login`

- **Python 3.10+**
  - [python.org/downloads](https://www.python.org/downloads/)

### Optionnel (Windows)

- **Git Bash** (recommandé)
  - [git-scm.com/download/win](https://git-scm.com/download/win)
  - Permet d'utiliser le même script que Linux/Mac

---

## 🚀 Installation

### Configuration Initiale

**1. Cloner ou télécharger le projet**

```bash
git clone https://github.com/TON_USERNAME/multimodal-rag-inf1900.git
cd multimodal-rag-inf1900
```

**2. Obtenir une clé API Gemini**

- Aller sur [aistudio.google.com/apikey](https://aistudio.google.com/apikey)
- Créer une clé API (gratuit)
- Sauvegarder la clé (sera demandée par le script)

**3. Créer un projet Google Cloud**

- Aller sur [console.cloud.google.com/projectcreate](https://console.cloud.google.com/projectcreate)
- Créer un projet (ex: `mon-rag-inf1900`)
- Noter le Project ID (sera demandé par le script)

---

### 🐧 Linux

**1. Installer les prérequis**

```bash
# Google Cloud SDK
curl https://sdk.cloud.google.com | bash
exec -l $SHELL
gcloud init

# Python 3.10+ (si pas déjà installé)
sudo apt update
sudo apt install python3.10 python3-pip
```

**2. Exécuter le script de setup**

```bash
cd multimodal-rag-inf1900
chmod +x setup.sh
./setup.sh
```

**3. Suivre les instructions**

Le script va demander:
- Project ID Google Cloud
- Clé API Gemini
- Si vous voulez ingérer la documentation (recommandé)

**4. Attendre le déploiement (~10-15 min)**

Le script va:
- ✅ Activer les APIs Google Cloud
- ✅ Configurer Secret Manager
- ✅ Ingérer la documentation (optionnel)
- ✅ Déployer le backend
- ✅ Déployer le frontend
- ✅ Afficher l'URL de l'application

---

### 🍎 macOS

**1. Installer les prérequis**

```bash
# Homebrew (si pas déjà installé)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Google Cloud SDK
brew install google-cloud-sdk
gcloud init

# Python 3.10+ (si pas déjà installé)
brew install python@3.10
```

**2. Exécuter le script de setup**

```bash
cd multimodal-rag-inf1900
chmod +x setup.sh
./setup.sh
```

**3. Suivre les instructions**

Identique à Linux (voir section Linux étape 3-4)

---

### 🪟 Windows

**Vous avez 3 options selon vos préférences:**

---

#### Option 1: Git Bash (RECOMMANDÉ - Même expérience que Linux/Mac)

**1. Installer Git for Windows**

- Télécharger: [git-scm.com/download/win](https://git-scm.com/download/win)
- Pendant l'installation, sélectionner "Git Bash Here"

**2. Installer Google Cloud SDK**

- Télécharger: [cloud.google.com/sdk/docs/install](https://cloud.google.com/sdk/docs/install)
- Installer et exécuter `gcloud init`

**3. Installer Python**

- Télécharger: [python.org/downloads](https://www.python.org/downloads/)
- Cocher "Add Python to PATH" pendant l'installation

**4. Exécuter le script dans Git Bash**

```bash
# Ouvrir Git Bash (clic droit → "Git Bash Here")
cd /c/Users/TON_USERNAME/Downloads/multimodal-rag-inf1900
chmod +x setup.sh
./setup.sh
```

**Avantages**:
- ✅ Même script que Linux/Mac
- ✅ Commandes identiques
- ✅ Meilleure compatibilité

---

#### Option 2: PowerShell (Natif Windows)

**1. Installer les prérequis** (Google Cloud SDK + Python, voir Option 1)

**2. Autoriser l'exécution de scripts** (une seule fois)

```powershell
# Ouvrir PowerShell en administrateur
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

**3. Exécuter le script PowerShell**

```powershell
cd C:\Users\TON_USERNAME\Downloads\multimodal-rag-inf1900
.\setup.ps1
```

**Avantages**:
- ✅ Natif Windows
- ✅ Jolies couleurs
- ✅ Pas besoin d'installer Git

---

#### Option 3: Command Prompt (Le plus simple)

**1. Installer les prérequis** (Google Cloud SDK + Python, voir Option 1)

**2. Exécuter le script**

```cmd
cd C:\Users\TON_USERNAME\Downloads\multimodal-rag-inf1900
setup.bat
```

**Avantages**:
- ✅ Aucune configuration
- ✅ Fonctionne immédiatement

---

## 💻 Utilisation

### Accéder à l'application

Après le déploiement, le script affiche:

```
╔════════════════════════════════════════════════════════════╗
║              🎉 DÉPLOIEMENT COMPLET RÉUSSI! 🎉             ║
╚════════════════════════════════════════════════════════════╝

🌐 VOTRE APPLICATION EST LIVE:

   👉 https://rag-frontend-xxxxx.run.app
```

**Ouvrir l'URL dans un navigateur** (Chrome/Firefox recommandé)

---

### Modes d'utilisation

#### 📝 Mode Texte

1. Taper une question dans le champ texte
2. Appuyer sur "📤 Envoyer"
3. Voir la réponse enrichie avec badge "📚 RAG"

**Exemple**:
```
Question: "Comment programmer le DDRD?"
Réponse: "Selon la documentation INF1900, DDRD (Data Direction Register D) 
         contrôle la direction des pins du PORTD..."
         [📚 RAG]
```

---

#### 📷 Mode Image

1. Cliquer sur "📷 Upload Image"
2. Sélectionner une image (circuit, code, schéma)
3. Voir l'analyse enrichie avec badge "📚 RAG"

**Exemple**:
```
Upload: photo_circuit.jpg
Analyse: "Ce circuit utilise un ATmega324PA avec LED sur PORTB. 
          Selon la doc, les résistances de 330Ω sont appropriées..."
          [📚 RAG]
```

---

#### 🎵 Mode Audio

1. Cliquer sur "🎵 Upload Audio"
2. Sélectionner un fichier audio (MP3, WAV, M4A)
3. Voir la transcription + réponse enrichie

**Exemple**:
```
Upload: question.mp3
Transcription: "Comment utiliser les interruptions?"
Réponse: "Selon la doc INF1900, les interruptions sur ATmega324PA..."
         [📚 RAG]
```

---

#### 🎨 Mode Génération

1. Cliquer sur "🎨 Générer Image"
2. Entrer un prompt (ex: "Schéma du registre PORTD")
3. Voir l'image générée avec specs techniques

**Exemple**:
```
Prompt: "Diagramme de connexion LED"
Image générée: Schéma technique avec composants, valeurs de résistances, etc.
               [📚 RAG - Prompt enrichi avec spécifications]
```

---

## 🔍 Comment ça marche

### Scripts de Déploiement

**3 scripts disponibles, tous font exactement la même chose:**

| Script | Pour | Shell |
|--------|------|-------|
| `setup.sh` | Linux, Mac, Git Bash (Windows) | Bash |
| `setup.ps1` | Windows PowerShell | PowerShell |
| `setup.bat` | Windows Command Prompt | Batch |

**Ce que font les scripts (étape par étape):**

#### 1. Vérifications (5 sec)
```
✅ gcloud CLI installé?
✅ Python installé?
```

#### 2. Configuration Projet (30 sec)
```
📝 Demande Project ID
🔍 Vérifie que le projet existe
⚙️  Configure gcloud avec ce projet
```

#### 3. Activation APIs (1-2 min)
```
🔌 Active Cloud Run
🔌 Active Cloud Build
🔌 Active Vertex AI
🔌 Active Secret Manager
```

#### 4. Configuration Gemini (10 sec)
```
🔑 Demande clé API Gemini
💾 Sauvegarde dans Secret Manager
```

#### 5. Ingestion Documentation (5-10 min, optionnel)
```
📚 Télécharge documentation INF1900
✂️  Découpe en chunks
🔢 Génère embeddings
💾 Stocke dans ChromaDB
```

#### 6. Déploiement Backend (3-5 min)
```
🏗️  Build container Docker
📤 Upload sur Google Container Registry
🚀 Déploie sur Cloud Run
🔗 Configure secrets et variables
```

#### 7. Déploiement Frontend (2-3 min)
```
🏗️  Build container Docker
📤 Upload sur Google Container Registry
🚀 Déploie sur Cloud Run
🔗 Configure connexion au backend
🌐 Active accès public
```

#### 8. Résumé (5 sec)
```
✅ Affiche URLs
✅ Affiche commandes utiles
✅ Affiche prochaines étapes
```

**Durée totale: ~15-20 minutes** (avec ingestion)

---

### Flux de Traitement Multimodal

#### Exemple: Question avec Image

```
1. FRONTEND (app.js)
   ├─ Utilisateur upload image "circuit.jpg"
   ├─ FileReader convertit en base64
   ├─ POST /upload-image
   │   Body: {
   │     "image": "iVBORw0KGgo...",
   │     "mimeType": "image/jpeg"
   │   }
   └─ Attend réponse

2. BACKEND (main.py - /upload-image)
   ├─ Reçoit image base64
   ├─ Décode base64 → bytes
   │
   ├─ ÉTAPE 1: Analyse initiale (Gemini Vision)
   │   ├─ Gemini.generate_content(
   │   │    "Analyse rapidement: circuit, code, texte",
   │   │    image_bytes
   │   │  )
   │   └─ Résultat: "Circuit avec LED sur PORTB"
   │
   ├─ ÉTAPE 2: RAG - Recherche contexte
   │   ├─ Query: "Circuit avec LED sur PORTB"
   │   ├─ ChromaDB.similarity_search(query, k=3)
   │   └─ Contexte: [
   │         "Doc GPIO PORTB...",
   │         "Doc LED 330Ω...",
   │         "Doc résistances..."
   │       ]
   │
   ├─ ÉTAPE 3: Réponse enrichie (Gemini + RAG)
   │   ├─ Prompt: """
   │   │    📚 Documentation:
   │   │    {contexte RAG}
   │   │    
   │   │    📷 Analyse: {analyse Vision}
   │   │    
   │   │    Combine analyse + doc
   │   │  """
   │   ├─ Gemini.generate_content(prompt, image_bytes)
   │   └─ Réponse: "Ce circuit utilise PORTB pour LED.
   │                 Selon la doc INF1900, résistances 330Ω..."
   │
   └─ Return: {
         "response": "Ce circuit...",
         "has_context": true,
         "rag_used": "✅ RAG utilisé"
       }

3. FRONTEND (app.js)
   ├─ Reçoit réponse JSON
   ├─ Détecte has_context = true
   ├─ Affiche message avec badge RAG
   └─ "🤖 Assistant [📚 RAG]: Ce circuit utilise..."
```

---

### ChromaDB et Embeddings

**Qu'est-ce qu'un embedding ?**

Un embedding transforme du texte en vecteur de nombres:

```
Texte: "DDRD contrôle la direction des pins"
    ↓ text-embedding-004
Vecteur: [0.123, -0.456, 0.789, ..., 0.234]  (768 dimensions)
```

**Recherche de similarité:**

```
Question: "Comment configurer DDRD?"
    ↓
Embedding: [0.145, -0.423, 0.801, ...]
    ↓
Similarité cosinus avec tous les vecteurs dans ChromaDB
    ↓
Top 3 plus similaires:
  1. "DDRD (Data Direction Register D) contrôle..." (score: 0.89)
  2. "Configuration des registres de direction..." (score: 0.85)
  3. "Exemple DDRD = 0xFF pour sortie..." (score: 0.82)
```

**Stockage dans ChromaDB:**

```
ChromaDB
├── Collection: "inf1900_docs"
│   ├── Document 1
│   │   ├── text: "DDRD contrôle..."
│   │   ├── embedding: [0.123, -0.456, ...]
│   │   └── metadata: {source: "registres.pdf", page: 12}
│   │
│   ├── Document 2
│   │   ├── text: "Les LEDs nécessitent..."
│   │   ├── embedding: [0.234, -0.567, ...]
│   │   └── metadata: {source: "led.pdf", page: 5}
│   │
│   └── ... (1000+ documents)
```

---

## 📁 Structure du projet

```
multimodal-rag-inf1900/
│
├── backend/                    # Backend FastAPI
│   ├── main.py                # Serveur principal + endpoints
│   ├── ingest.py              # Script d'ingestion ChromaDB
│   ├── requirements.txt       # Dépendances Python
│   ├── Dockerfile             # Container backend
│   └── inf1900_db/            # ChromaDB (après ingestion)
│       ├── chroma.sqlite3
│       └── ...
│
├── frontend/                   # Frontend web
│   ├── index.html             # Interface utilisateur
│   ├── app.js                 # Logique frontend
│   ├── server.py              # Serveur FastAPI (fichiers statiques)
│   ├── requirements.txt       # Dépendances Python
│   ├── Dockerfile             # Container frontend
│   └── background.png         # Image de fond (optionnel)
│
├── docs/                       # Documentation (pour ingestion)
│   ├── registres.pdf
│   ├── gpio.pdf
│   ├── atmel_datasheet.pdf
│   └── ...
│
├── cloudbuild.yaml            # Configuration Cloud Build (backend)
├── cloudbuild_frontend.yaml   # Configuration Cloud Build (frontend)
│
├── setup.sh                   # Script setup Linux/Mac/Git Bash
├── setup.ps1                  # Script setup Windows PowerShell
├── setup.bat                  # Script setup Windows CMD
│
└── README.md                  # Ce fichier
```

---

## 🛠️ Technologies

### Backend

| Technologie | Version | Usage |
|-------------|---------|-------|
| **Python** | 3.10+ | Langage principal |
| **FastAPI** | 0.115+ | Framework web API |
| **LangChain** | 0.3+ | Orchestration RAG |
| **ChromaDB** | 0.4.24 | Vector database |
| **Google Gemini** | 2.5 Flash | LLM + Vision + Audio |
| **Vertex AI** | Latest | Génération d'images (Imagen) |

### Frontend

| Technologie | Version | Usage |
|-------------|---------|-------|
| **HTML5** | - | Structure |
| **JavaScript** | ES6+ | Logique |
| **FastAPI** | 0.115+ | Serveur statique |

### Infrastructure

| Service | Usage |
|---------|-------|
| **Cloud Run** | Hosting backend + frontend |
| **Cloud Build** | CI/CD |
| **Secret Manager** | Stockage sécurisé clés API |
| **Container Registry** | Stockage images Docker |

---

## 🔧 Développement

### Lancer localement

#### Backend

```bash
cd backend

# Créer environnement virtuel
python -m venv venv
source venv/bin/activate  # Linux/Mac
# OU
venv\Scripts\activate  # Windows

# Installer dépendances
pip install -r requirements.txt

# Configurer variables
export GEMINI_API_KEY="ta_clé"
export GCP_PROJECT_ID="ton_projet"

# Lancer serveur
python main.py
# → http://localhost:8080
```

#### Frontend

```bash
cd frontend

# Créer environnement virtuel
python -m venv venv
source venv/bin/activate  # Linux/Mac

# Installer dépendances
pip install -r requirements.txt

# Configurer backend URL
export BACKEND_URL="http://localhost:8080"

# Lancer serveur
python server.py
# → http://localhost:8000
```

---

### Ingestion de nouvelle documentation

```bash
cd backend

# Activer environnement
source venv/bin/activate

# Ajouter PDFs dans docs/
cp nouveau_doc.pdf docs/

# Exporter clé Gemini
export GOOGLE_API_KEY="ta_clé"

# Lancer ingestion
python ingest.py

# Résultat dans inf1900_db/
```

---

### Redéploiement

#### Backend seulement
```bash
export PROJECT_ID=ton_projet
gcloud builds submit --config cloudbuild.yaml --project=$PROJECT_ID
```

#### Frontend seulement
```bash
export PROJECT_ID=ton_projet
gcloud builds submit --config cloudbuild_frontend.yaml --project=$PROJECT_ID
```

#### Les deux
```bash
export PROJECT_ID=ton_projet
gcloud builds submit --config cloudbuild.yaml --project=$PROJECT_ID
gcloud builds submit --config cloudbuild_frontend.yaml --project=$PROJECT_ID
```

---

## 🐛 Dépannage

### Problème: "gcloud: command not found"

**Solution**: Installer Google Cloud SDK

```bash
# Linux
curl https://sdk.cloud.google.com | bash
exec -l $SHELL

# Mac
brew install google-cloud-sdk

# Windows
# Télécharger depuis: https://cloud.google.com/sdk/docs/install
```

---

### Problème: "Permission denied" (Linux/Mac)

**Solution**: Rendre le script exécutable

```bash
chmod +x setup.sh
./setup.sh
```

---

### Problème: "Execution policy" (Windows PowerShell)

**Solution**: Autoriser les scripts

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
.\setup.ps1
```

---

### Problème: Image background invisible en production

**Solution**: Utiliser base64 ou modifier Dockerfile

Voir le guide complet: `GUIDE_FIX_IMAGE_BACKGROUND.md`

**Quick fix**:
```bash
# Convertir image en base64
python convert_image_to_base64.py background.png

# Copier le code généré dans index.html
# Redéployer
```

---

### Problème: RAG ne trouve rien

**Solutions**:

1. **Vérifier que l'ingestion a été faite**:
```bash
cd backend
ls -la inf1900_db/  # Doit contenir chroma.sqlite3
```

2. **Réingérer la documentation**:
```bash
cd backend
source venv/bin/activate
export GOOGLE_API_KEY="ta_clé"
python ingest.py
```

3. **Vérifier les logs**:
```bash
gcloud run logs tail multimodal-rag-inf1900 --project=ton_projet
```

---

### Problème: Upload audio ne marche pas

**Vérifier**:

1. Format supporté (MP3, WAV, M4A, WebM, OGG)
2. Taille < 10MB
3. Logs backend pour erreurs

```bash
gcloud run logs tail multimodal-rag-inf1900 --project=ton_projet
```

---

### Problème: Génération d'images échoue

**Solution**: Vérifier que Vertex AI est activé

```bash
gcloud services enable aiplatform.googleapis.com --project=ton_projet
```

---

## 🎓 Exemples d'Utilisation

### Exemple 1: Question sur les registres

**Input (Texte)**:
```
"Quelle est la différence entre DDRD et PORTD?"
```

**Processing**:
1. RAG cherche dans la doc: "DDRD", "PORTD", "registres"
2. Trouve 3 documents pertinents
3. Gemini génère réponse avec contexte

**Output**:
```
🤖 Assistant [📚 RAG]:

Selon la documentation INF1900:

• DDRD (Data Direction Register D): Configure la DIRECTION des pins
  - DDRD = 0xFF → Toutes les pins en sortie
  - DDRD = 0x00 → Toutes les pins en entrée

• PORTD (Port D Data Register): Écrit les VALEURS sur les pins
  - PORTD = 0xFF → Toutes les pins à HIGH (5V)
  - PORTD = 0x00 → Toutes les pins à LOW (0V)

Exemple: LED sur PD0
  DDRD |= (1 << PD0);   // Configure PD0 en sortie
  PORTD |= (1 << PD0);  // Allume LED (HIGH)
```

---

### Exemple 2: Analyse de circuit

**Input (Image)**:
```
[Upload: photo_circuit_led.jpg]
```

**Processing**:
1. Gemini Vision analyse: "Circuit avec LED, résistance 330Ω, ATmega324PA"
2. RAG cherche: "LED 330Ω ATmega324PA GPIO"
3. Gemini combine Vision + RAG

**Output**:
```
🤖 Assistant [📚 RAG]:

📷 Analyse du circuit:

• Microcontrôleur: ATmega324PA
• LED rouge connectée sur PORTB (probablement PB0)
• Résistance: 330Ω (orange-orange-marron)

Selon la documentation INF1900:

✅ La résistance de 330Ω est correcte pour une LED standard
   - Tension LED: ~2V
   - Courant LED: ~10mA
   - Calcul: R = (5V - 2V) / 10mA = 300Ω

Code correspondant:
  DDRB |= (1 << PB0);   // Configure PB0 en sortie
  PORTB |= (1 << PB0);  // Allume LED
```

---

### Exemple 3: Transcription de question audio

**Input (Audio)**:
```
[Upload: question_interruptions.mp3]
Contenu audio: "Comment fonctionnent les interruptions sur l'ATmega?"
```

**Processing**:
1. Gemini transcrit: "Comment fonctionnent les interruptions sur l'ATmega?"
2. RAG cherche: "interruptions ATmega"
3. Gemini génère réponse avec contexte

**Output**:
```
👤 Vous: 📝 Transcription: "Comment fonctionnent les interruptions sur l'ATmega?"

🤖 Assistant [📚 RAG]:

Selon la documentation INF1900:

Les interruptions sur l'ATmega324PA permettent de réagir à des événements
sans polling constant:

1. VECTEURS D'INTERRUPTION:
   - INT0, INT1, INT2: Interruptions externes
   - TIMER0_OVF, TIMER1_OVF: Débordements timers
   - USART_RX, USART_TX: Communication série

2. CONFIGURATION:
   cli();                    // Désactiver interruptions globales
   EIMSK |= (1 << INT0);    // Activer INT0
   EICRA |= (1 << ISC01);   // Front descendant
   sei();                    // Activer interruptions globales

3. GESTIONNAIRE (ISR):
   ISR(INT0_vect) {
       // Code exécuté lors de l'interruption
   }
```

---

### Exemple 4: Génération de schéma

**Input (Génération)**:
```
Prompt: "Schéma de connexion d'un servo-moteur sur l'ATmega324PA"
```

**Processing**:
1. RAG cherche: "servo-moteur ATmega324PA PWM"
2. Enrichit prompt avec spécifications techniques
3. Imagen génère schéma

**Output**:
```
🤖 Assistant [📚 RAG]:

✅ Image générée avec RAG: "Schéma de connexion d'un servo-moteur"

[Image affichée: Schéma technique montrant]
- ATmega324PA
- Servo-moteur
- Connexions PWM (PD5/OC1A)
- Alimentation 5V
- Labels et annotations
```

---

## 📊 Métriques et Performances

### Temps de Réponse Typiques

| Mode | Temps | Composantes |
|------|-------|-------------|
| **Texte** | ~2-3s | RAG (0.5s) + Gemini (1.5s) |
| **Image** | ~3-5s | Vision (1s) + RAG (0.5s) + Gemini (2s) |
| **Audio** | ~5-8s | Transcription (2s) + RAG (0.5s) + Gemini (2s) |
| **Génération** | ~10-15s | RAG (0.5s) + Imagen (10s) |

### Coûts Estimés (par 1000 requêtes)

| Service | Coût | Notes |
|---------|------|-------|
| **Cloud Run** | ~$0.10 | Backend + Frontend |
| **Gemini API** | ~$0.50 | Texte + Vision + Audio |
| **Vertex AI Imagen** | ~$4.00 | Génération d'images |
| **Total** | **~$4.60** | Très économique! |

**Crédits gratuits**: $300 sur Google Cloud = ~65,000 requêtes!

---

## 🤝 Contribuer

Les contributions sont les bienvenues!

### Comment contribuer

1. **Fork le projet**
2. **Créer une branche** (`git checkout -b feature/AmazingFeature`)
3. **Commit les changements** (`git commit -m 'Add AmazingFeature'`)
4. **Push sur la branche** (`git push origin feature/AmazingFeature`)
5. **Ouvrir une Pull Request**

### Idées de contributions

- 📚 Ajouter plus de documentation dans `docs/`
- 🎨 Améliorer l'interface utilisateur
- 🔧 Optimiser le RAG (meilleurs prompts, chunking)
- 🌍 Support multilingue
- 📊 Dashboard analytics
- 🎤 Enregistrement audio dans le navigateur
- 📱 Version mobile

---

## 📄 Licence

MIT License - Voir le fichier LICENSE pour plus de détails

---

## 👥 Auteurs

- **Hassib Ezzedine** - Projet Multimodal RAG INF1900

---

## 🙏 Remerciements

- **Polytechnique Montréal** - Cours INF1900
- **Google Cloud** - Infrastructure et APIs
- **Anthropic** - Documentation et support
- **Communauté Open Source** - LangChain, ChromaDB, FastAPI

---

## 📚 Documentation Additionnelle

- [Architecture Détaillée](docs/ARCHITECTURE.md)
- [Guide RAG](docs/RAG_GUIDE.md)
- [API Reference](docs/API.md)
- [Déploiement Avancé](docs/DEPLOYMENT.md)

---

## 🔗 Liens Utiles

- [Google Cloud Console](https://console.cloud.google.com)
- [Gemini API](https://aistudio.google.com)
- [FastAPI Documentation](https://fastapi.tiangolo.com)
- [LangChain Documentation](https://python.langchain.com)
- [ChromaDB Documentation](https://docs.trychroma.com)

---

## 📞 Support

**Problème technique ?**
1. Vérifier la section [Dépannage](#-dépannage)
2. Consulter les logs: `gcloud run logs tail SERVICE_NAME`
3. Ouvrir une issue sur GitHub

**Question sur le cours INF1900 ?**
- Utiliser l'application directement! C'est fait pour ça! 😊

---

**🎉 Bon apprentissage avec votre assistant RAG multimodal! 🎉**