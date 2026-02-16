@echo off
REM ============================================================================
REM Setup Script COMPLET - Multimodal RAG INF1900 (WINDOWS CMD)
REM Deploie: Backend + Frontend en une seule commande
REM Usage: setup.bat
REM ============================================================================

setlocal enabledelayedexpansion

echo.
echo ================================================================
echo    Multimodal RAG INF1900 - Deploiement Complet
echo    Backend + Frontend en une seule commande
echo ================================================================
echo.

REM ============================================================================
REM 1. VERIFICATIONS
REM ============================================================================

echo Verification des prerequis...
echo.

where gcloud >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo [ERREUR] gcloud CLI manquant
    echo Installez-le: https://cloud.google.com/sdk/docs/install
    pause
    exit /b 1
)
echo [OK] gcloud CLI

where python >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo [ERREUR] Python manquant
    echo Installez-le: https://www.python.org/downloads/
    pause
    exit /b 1
)
echo [OK] Python
echo.

REM ============================================================================
REM 1b. VERIFICATION AUTHENTIFICATION GCLOUD
REM ============================================================================

echo Verification authentification gcloud...
gcloud auth list --filter=status:ACTIVE --format="value(account)" >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo [ATTENTION] Vous n'etes pas authentifie avec gcloud !
    echo.
    echo Authentifiez-vous maintenant...
    gcloud auth login
    if %ERRORLEVEL% NEQ 0 (
        echo [ERREUR] Authentification echouee
        pause
        exit /b 1
    )
)
echo [OK] Authentification gcloud
echo.

REM ============================================================================
REM 2. CONFIGURATION PROJET
REM ============================================================================

echo Configuration Google Cloud...
echo.
echo Creez votre projet sur:
echo   https://console.cloud.google.com/projectcreate
echo.
echo Ou utilisez un projet existant.
echo.

set /p PROJECT_ID="Project ID: "

if "%PROJECT_ID%"=="" (
    echo [ERREUR] Project ID requis
    pause
    exit /b 1
)

echo.
echo Verification du projet: %PROJECT_ID%
echo.

REM Tenter de decrire le projet et capturer la sortie
gcloud projects describe %PROJECT_ID% >nul 2>&1

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo [ERREUR] Impossible d'acceder au projet: %PROJECT_ID%
    echo.
    echo Causes possibles:
    echo   1. Le projet n'existe pas
    echo   2. Vous n'avez pas acces a ce projet
    echo   3. Le Project ID est incorrect
    echo.
    echo Verifiez vos projets disponibles:
    echo   https://console.cloud.google.com/cloud-resource-manager
    echo.
    echo Ou listez vos projets avec:
    echo   gcloud projects list
    echo.
    pause
    exit /b 1
)

echo [OK] Projet trouve: %PROJECT_ID%
echo.
echo Configuration du projet par defaut...
gcloud config set project %PROJECT_ID%
echo [OK] Projet configure
echo.

REM ============================================================================
REM 3. ACTIVATION APIs
REM ============================================================================

echo Activation des APIs...
echo.
echo NOTE: Cette etape peut prendre 1-2 minutes...
echo.

echo   Activation de run.googleapis.com...
gcloud services enable run.googleapis.com --project=%PROJECT_ID% --quiet 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo   [ATTENTION] Erreur lors de l'activation de Cloud Run
)

echo   Activation de cloudbuild.googleapis.com...
gcloud services enable cloudbuild.googleapis.com --project=%PROJECT_ID% --quiet 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo   [ATTENTION] Erreur lors de l'activation de Cloud Build
)

echo   Activation de aiplatform.googleapis.com...
gcloud services enable aiplatform.googleapis.com --project=%PROJECT_ID% --quiet 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo   [ATTENTION] Erreur lors de l'activation de Vertex AI
)

echo   Activation de secretmanager.googleapis.com...
gcloud services enable secretmanager.googleapis.com --project=%PROJECT_ID% --quiet 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo   [ATTENTION] Erreur lors de l'activation de Secret Manager
)

echo.
echo [OK] APIs activees
echo.

REM ============================================================================
REM 4. CLE GEMINI
REM ============================================================================

echo Configuration Gemini...
echo.
echo Obtenez votre cle API Gemini (GRATUITE):
echo   https://aistudio.google.com/apikey
echo.

set /p GEMINI_KEY="Cle API Gemini: "

if "%GEMINI_KEY%"=="" (
    echo [ERREUR] Cle requise
    pause
    exit /b 1
)

echo.
echo Sauvegarde dans Secret Manager...

REM Tenter de creer le secret
echo %GEMINI_KEY% | gcloud secrets create gemini-api-key --data-file=- --project=%PROJECT_ID% 2>nul

if %ERRORLEVEL% NEQ 0 (
    echo Secret existe deja, mise a jour...
    echo %GEMINI_KEY% | gcloud secrets versions add gemini-api-key --data-file=- --project=%PROJECT_ID%
    if %ERRORLEVEL% NEQ 0 (
        echo [ERREUR] Impossible de sauvegarder la cle
        pause
        exit /b 1
    )
)

echo [OK] Cle sauvegardee dans Secret Manager
echo.

REM ============================================================================
REM 5. INGESTION (OPTIONNEL)
REM ============================================================================

echo Ingestion de la base de connaissances...
echo.
echo Cette etape est OPTIONNELLE mais recommandee.
echo Elle prend environ 5-10 minutes.
echo.
set /p DO_INGEST="Ingerer la documentation maintenant? (o/N): "

if /i "%DO_INGEST%"=="o" (
    echo.
    echo Configuration de l'environnement Python...
    
    REM Verifier si backend/requirements.txt existe
    if not exist "backend\requirements.txt" (
        echo [ERREUR] Fichier backend\requirements.txt introuvable
        echo Assurez-vous d'etre dans le dossier multimodal-rag-inf1900
        pause
        exit /b 1
    )
    
    python -m venv venv
    if %ERRORLEVEL% NEQ 0 (
        echo [ERREUR] Impossible de creer l'environnement virtuel
        pause
        exit /b 1
    )
    
    call venv\Scripts\activate.bat
    
    echo Installation des dependances...
    python -m pip install --upgrade pip --quiet
    pip install -r backend\requirements.txt --quiet
    
    echo.
    echo Debut de l'ingestion (5-10 min)...
    echo.
    set GOOGLE_API_KEY=%GEMINI_KEY%
    python backend\ingest.py
    
    if %ERRORLEVEL% NEQ 0 (
        echo.
        echo [ATTENTION] L'ingestion a echoue
        echo Vous pourrez la relancer plus tard avec:
        echo   python backend\ingest.py
        echo.
    ) else (
        echo [OK] Ingestion terminee avec succes
    )
    
    call venv\Scripts\deactivate.bat
    rmdir /s /q venv
    echo.
) else (
    echo Ingestion ignoree
    echo.
    echo Vous pourrez l'executer plus tard avec:
    echo   cd backend
    echo   python -m venv venv
    echo   venv\Scripts\activate
    echo   pip install -r requirements.txt
    echo   set GOOGLE_API_KEY=VOTRE_CLE
    echo   python ingest.py
    echo.
)

REM ============================================================================
REM 6. DEPLOIEMENT BACKEND
REM ============================================================================

echo.
echo ================================================================
echo          DEPLOIEMENT BACKEND
echo ================================================================
echo.

REM Verifier que cloudbuild.yaml existe
if not exist "cloudbuild.yaml" (
    echo [ERREUR] Fichier cloudbuild.yaml introuvable
    echo Assurez-vous d'etre dans le dossier multimodal-rag-inf1900
    pause
    exit /b 1
)

echo Build et deploiement du backend...
echo NOTE: Cette etape peut prendre 10-15 minutes...
echo.

gcloud builds submit --config cloudbuild.yaml --project=%PROJECT_ID%

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo [ERREUR] Le deploiement du backend a echoue
    echo.
    echo Verifiez:
    echo   1. Que Cloud Build API est activee
    echo   2. Que vous avez les permissions necessaires
    echo   3. Les logs sur: https://console.cloud.google.com/cloud-build
    echo.
    pause
    exit /b 1
)

echo.
echo Recuperation de l'URL du backend...
for /f "delims=" %%i in ('gcloud run services describe multimodal-rag-inf1900 --region^=us-central1 --project^=%PROJECT_ID% --format^="value(status.url)" 2^>nul') do set BACKEND_URL=%%i

if "%BACKEND_URL%"=="" (
    echo [ERREUR] Impossible de recuperer l'URL du backend
    echo.
    echo Verifiez le deploiement sur:
    echo   https://console.cloud.google.com/run?project=%PROJECT_ID%
    echo.
    pause
    exit /b 1
)

echo [OK] Backend deploye: %BACKEND_URL%
echo.

REM ============================================================================
REM 7. DEPLOIEMENT FRONTEND
REM ============================================================================

echo.
echo ================================================================
echo          DEPLOIEMENT FRONTEND
echo ================================================================
echo.

REM Verifier que cloudbuild_frontend.yaml existe
if not exist "cloudbuild_frontend.yaml" (
    echo [ERREUR] Fichier cloudbuild_frontend.yaml introuvable
    echo Assurez-vous d'etre dans le dossier multimodal-rag-inf1900
    pause
    exit /b 1
)

echo Build et deploiement du frontend...
echo NOTE: Cette etape peut prendre 5-8 minutes...
echo.

gcloud builds submit --config cloudbuild_frontend.yaml --project=%PROJECT_ID%

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo [ERREUR] Le deploiement du frontend a echoue
    echo.
    echo Verifiez les logs sur:
    echo   https://console.cloud.google.com/cloud-build?project=%PROJECT_ID%
    echo.
    pause
    exit /b 1
)

echo.
echo Configuration de la connexion Frontend - Backend...
gcloud run services update rag-frontend --region=us-central1 --set-env-vars=BACKEND_URL=%BACKEND_URL% --project=%PROJECT_ID% --quiet

echo.
echo Autorisation des acces publics...
gcloud run services add-iam-policy-binding rag-frontend --region=us-central1 --member="allUsers" --role="roles/run.invoker" --project=%PROJECT_ID% --quiet 2>nul

echo.
echo Recuperation de l'URL du frontend...
for /f "delims=" %%i in ('gcloud run services describe rag-frontend --region^=us-central1 --project^=%PROJECT_ID% --format^="value(status.url)" 2^>nul') do set FRONTEND_URL=%%i

if "%FRONTEND_URL%"=="" (
    echo [ERREUR] Impossible de recuperer l'URL du frontend
    echo.
    echo Verifiez le deploiement sur:
    echo   https://console.cloud.google.com/run?project=%PROJECT_ID%
    echo.
    pause
    exit /b 1
)

echo [OK] Frontend deploye: %FRONTEND_URL%
echo.

REM ============================================================================
REM 8. RESUME FINAL
REM ============================================================================

echo.
echo.
echo ================================================================
echo          DEPLOIEMENT COMPLET REUSSI!
echo ================================================================
echo.
echo Architecture Deployee:
echo ----------------------------------------------------------------
echo.
echo FRONTEND (Interface Utilisateur)
echo    URL:     %FRONTEND_URL%
echo    Service: rag-frontend
echo    Stack:   HTML/JS + FastAPI
echo.
echo BACKEND (API Multimodale)
echo    URL:     %BACKEND_URL%
echo    Service: multimodal-rag-inf1900
echo    Stack:   FastAPI + Gemini + ChromaDB
echo.
echo PROJET GOOGLE CLOUD
echo    ID:      %PROJECT_ID%
echo    Region:  us-central1
echo.
echo ----------------------------------------------------------------
echo.
echo VOTRE APPLICATION EST LIVE:
echo.
echo    ^>^> %FRONTEND_URL%
echo.
echo ----------------------------------------------------------------
echo.
echo Fonctionnalites Disponibles:
echo.
echo    Texte:  Tapez vos questions
echo    Images: Upload pour OCR + analyse
echo    Audio:  Upload fichier audio
echo    RAG:    Documentation INF1900 integree
echo.
echo ----------------------------------------------------------------
echo.
echo Commandes Utiles:
echo.
echo   Logs Backend:
echo     gcloud run logs tail multimodal-rag-inf1900 --project=%PROJECT_ID%
echo.
echo   Logs Frontend:
echo     gcloud run logs tail rag-frontend --project=%PROJECT_ID%
echo.
echo   Redployer Backend:
echo     gcloud builds submit --config cloudbuild.yaml --project=%PROJECT_ID%
echo.
echo   Redployer Frontend:
echo     gcloud builds submit --config cloudbuild_frontend.yaml --project=%PROJECT_ID%
echo.
echo ----------------------------------------------------------------
echo.
echo Prochaines Etapes:
echo.
echo   1. Ouvrez: %FRONTEND_URL%
echo   2. Testez les modes:
echo      - Tapez une question
echo      - Uploadez une image de circuit
echo      - Uploadez un fichier audio
echo.
echo ================================================================
echo.
echo Bon apprentissage avec votre assistant multimodal INF1900!
echo.
pause