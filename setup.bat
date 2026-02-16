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
REM 2. CONFIGURATION PROJET
REM ============================================================================

echo Configuration Google Cloud...
echo.
echo Creez votre projet sur:
echo   https://console.cloud.google.com/projectcreate
echo.

set /p PROJECT_ID="Project ID: "

if "%PROJECT_ID%"=="" (
    echo [ERREUR] Project ID requis
    pause
    exit /b 1
)

echo Verification du projet...
gcloud projects describe %PROJECT_ID% >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo [ERREUR] Projet inexistant ou inaccessible
    pause
    exit /b 1
)

gcloud config set project %PROJECT_ID%
echo [OK] Projet: %PROJECT_ID%
echo.

REM ============================================================================
REM 3. ACTIVATION APIs
REM ============================================================================

echo Activation des APIs...
echo.

echo   - run.googleapis.com
gcloud services enable run.googleapis.com --project=%PROJECT_ID% --quiet

echo   - cloudbuild.googleapis.com
gcloud services enable cloudbuild.googleapis.com --project=%PROJECT_ID% --quiet

echo   - aiplatform.googleapis.com
gcloud services enable aiplatform.googleapis.com --project=%PROJECT_ID% --quiet

echo   - secretmanager.googleapis.com
gcloud services enable secretmanager.googleapis.com --project=%PROJECT_ID% --quiet

echo [OK] APIs activees
echo.

REM ============================================================================
REM 4. CLE GEMINI
REM ============================================================================

echo Configuration Gemini...
echo.
echo Obtenez votre cle: https://aistudio.google.com/apikey
echo.

set /p GEMINI_KEY="Cle API Gemini: "

if "%GEMINI_KEY%"=="" (
    echo [ERREUR] Cle requise
    pause
    exit /b 1
)

echo Sauvegarde dans Secret Manager...
echo %GEMINI_KEY% | gcloud secrets create gemini-api-key --data-file=- --project=%PROJECT_ID% 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo %GEMINI_KEY% | gcloud secrets versions add gemini-api-key --data-file=- --project=%PROJECT_ID%
)

echo [OK] Cle sauvegardee
echo.

REM ============================================================================
REM 5. INGESTION (OPTIONNEL)
REM ============================================================================

echo Ingestion de la base de connaissances...
set /p DO_INGEST="Ingerer maintenant? (o/N): "

if /i "%DO_INGEST%"=="o" (
    echo Configuration Python...
    
    python -m venv venv
    call venv\Scripts\activate.bat
    
    python -m pip install --upgrade pip --quiet
    pip install -r backend\requirements.txt --quiet
    
    echo Ingestion (5-10 min)...
    set GOOGLE_API_KEY=%GEMINI_KEY%
    python backend\ingest.py
    
    call venv\Scripts\deactivate.bat
    rmdir /s /q venv
    
    echo [OK] Ingestion terminee
) else (
    echo Ingestion ignoree
)
echo.

REM ============================================================================
REM 6. DEPLOIEMENT BACKEND
REM ============================================================================

echo ================================================================
echo          DEPLOIEMENT BACKEND
echo ================================================================
echo.

echo Build et deploiement du backend...
gcloud builds submit --config cloudbuild.yaml --project=%PROJECT_ID%

echo.
echo Recuperation URL backend...
for /f "delims=" %%i in ('gcloud run services describe multimodal-rag-inf1900 --region^=us-central1 --project^=%PROJECT_ID% --format^="value(status.url)" 2^>nul') do set BACKEND_URL=%%i

if "%BACKEND_URL%"=="" (
    echo [ERREUR] Impossible de recuperer l'URL du backend
    pause
    exit /b 1
)

echo [OK] Backend deploye: %BACKEND_URL%
echo.

REM ============================================================================
REM 7. DEPLOIEMENT FRONTEND
REM ============================================================================

echo ================================================================
echo          DEPLOIEMENT FRONTEND
echo ================================================================
echo.

echo Build et deploiement du frontend...
gcloud builds submit --config cloudbuild_frontend.yaml --project=%PROJECT_ID%

echo.
echo Configuration de la connexion Frontend - Backend...
gcloud run services update rag-frontend --region=us-central1 --set-env-vars=BACKEND_URL=%BACKEND_URL% --project=%PROJECT_ID% --quiet

echo.
echo Autorisation des acces publics...
gcloud run services add-iam-policy-binding rag-frontend --region=us-central1 --member="allUsers" --role="roles/run.invoker" --project=%PROJECT_ID% --quiet

echo.
echo Recuperation URL frontend...
for /f "delims=" %%i in ('gcloud run services describe rag-frontend --region^=us-central1 --project^=%PROJECT_ID% --format^="value(status.url)" 2^>nul') do set FRONTEND_URL=%%i

if "%FRONTEND_URL%"=="" (
    echo [ERREUR] Impossible de recuperer l'URL du frontend
    pause
    exit /b 1
)

echo [OK] Frontend deploye: %FRONTEND_URL%
echo.

REM ============================================================================
REM 8. RESUME FINAL
REM ============================================================================

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