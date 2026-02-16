# 🚀 Guide de Déploiement - Multimodal RAG INF1900

## Temps estimé: 30 minutes

Ce guide vous accompagne pas à pas dans le déploiement de votre assistant multimodal sur Google Cloud.

---

## 📋 Checklist Avant de Commencer

- [ ] Compte Google (Gmail)
- [ ] Ordinateur avec accès Internet
- [ ] Terminal/Command Prompt

**Tout le reste sera installé pendant ce guide!**

---

## Étape 1: Créer un Compte Google Cloud (5 min)

### 1.1 S'inscrire

1. Allez sur: https://console.cloud.google.com
2. Cliquez sur "Try for free" / "Essayer gratuitement"
3. Connectez-vous avec votre compte Google (@polymtl.ca ou personnel)
4. **Important**: Remplissez les informations de facturation
   - ✅ Vous recevrez **300$ de crédits gratuits**
   - ✅ Aucun frais ne sera prélevé sans votre autorisation
   - ✅ Le workshop reste dans le free tier (0$)

### 1.2 Créer votre Projet

1. Allez sur: https://console.cloud.google.com/projectcreate
2. **Nom du projet**: Choisissez quelque chose d'UNIQUE
   ```
   Exemples:
   - alice-inf1900-rag-2025
   - bob-multimodal-workshop
   - charlie-rag-assistant
   
   ❌ Évitez: multimodal-rag-inf1900 (trop générique)
   ```
3. **Project ID**: Sera généré automatiquement
   - Exemple: `alice-inf1900-rag-2025-abc123`
   - **📝 COPIEZ-LE** quelque part (vous en aurez besoin!)
4. Cliquez "CREATE" / "CRÉER"

---

## Étape 2: Obtenir une Clé API Gemini (3 min)

1. Allez sur: https://aistudio.google.com
2. Cliquez "Get API Key" en haut à droite
3. Sélectionnez "Create API key in new project" ou utilisez votre projet
4. **📝 COPIEZ LA CLÉ** immédiatement
   - Elle ressemble à: `AIzaSyD...`
   - ⚠️ Elle ne sera plus affichée après!
5. Sauvegardez-la dans un fichier texte temporaire

---

## Étape 3: Installer gcloud CLI (10 min)

### 🍎 macOS

```bash
# Méthode 1: Homebrew (recommandé)
brew install google-cloud-sdk

# Méthode 2: Script d'installation
curl https://sdk.cloud.google.com | bash
exec -l $SHELL
```

### 🐧 Linux

```bash
curl https://sdk.cloud.google.com | bash
exec -l $SHELL
gcloud init
```

### 🪟 Windows

1. Téléchargez: https://cloud.google.com/sdk/docs/install-sdk#windows
2. Exécutez l'installeur `GoogleCloudSDKInstaller.exe`
3. Suivez les instructions
4. Ouvrez un nouveau terminal PowerShell

### ✅ Vérifier l'Installation

```bash
gcloud --version
```

Vous devriez voir quelque chose comme:
```
Google Cloud SDK 460.0.0
...
```

---

## Étape 4: Configuration Initiale (5 min)

### 4.1 Login

```bash
gcloud auth login
```

Une page web s'ouvre → Connectez-vous avec votre compte Google

### 4.2 Configurer le Projet

```bash
# Remplacez par VOTRE Project ID copié à l'étape 1.2
gcloud config set project alice-inf1900-rag-2025-abc123
```

### 4.3 Vérifier

```bash
gcloud config get-value project
```

Ça devrait afficher votre Project ID.

---

## Étape 5: Déploiement Automatique (7 min)

### 5.1 Cloner le Repository

```bash
# Dans votre terminal
git clone https://github.com/votre-org/multimodal-rag-inf1900
cd multimodal-rag-inf1900
```

### 5.2 Rendre le Script Exécutable

```bash
chmod +x setup.sh
```

### 5.3 Lancer le Setup

```bash
./setup.sh
```

Le script va vous demander:

**1. Project ID:**
```
📝 Entrez votre Project ID Google Cloud:
```
→ Tapez le Project ID copié à l'étape 1.2

**2. Clé API Gemini:**
```
🔑 Entrez votre clé API Gemini:
```
→ Tapez la clé copiée à l'étape 2

**3. Ingestion (optionnel):**
```
Voulez-vous ingérer les données maintenant? (o/N):
```
→ Tapez `o` puis ENTRÉE (recommandé pour avoir toute la documentation)

**4. Méthode de déploiement:**
```
Choisissez (1 ou 2):
```
→ Tapez `1` (Cloud Build, plus simple)

### 5.4 Attendre...

Le déploiement prend **5-10 minutes**. Vous verrez:

```
🏗️  Build de l'image Docker...
📤 Push vers Container Registry...
🚀 Déploiement sur Cloud Run...
```

☕ Profitez-en pour prendre un café!

---

## Étape 6: Tester votre Application (5 min)

### 6.1 Récupérer l'URL

À la fin du script, vous verrez:

```
✅ DÉPLOIEMENT RÉUSSI!
🌐 Votre application:
  https://multimodal-rag-inf1900-xxxxx-uc.a.run.app
```

**📝 COPIEZ CETTE URL** (c'est votre application!)

### 6.2 Ouvrir l'Application

1. Copiez l'URL dans votre navigateur
2. Vous devriez voir l'interface de l'assistant
3. Cliquez "🎤 Commencer la Conversation"
4. **Autorisez l'accès au micro** quand demandé

### 6.3 Première Question

Essayez:
```
"Bonjour! Explique-moi comment fonctionne le registre DDRA sur l'ATmega324PA"
```

Vous devriez:
- Entendre une réponse vocale
- Voir le texte s'afficher
- Voir les sources citées

---

## 🎉 Félicitations!

Vous avez déployé votre assistant multimodal! 🚀

---

## 🔧 Dépannage

### Problème 1: "Project not found"

**Symptôme**: Le script dit que votre projet n'existe pas

**Solution**:
```bash
# Vérifier que vous êtes connecté au bon compte
gcloud auth list

# Vérifier vos projets
gcloud projects list

# Reconfigurer si besoin
gcloud config set project VOTRE-PROJECT-ID
```

### Problème 2: "Billing not enabled"

**Symptôme**: Message d'erreur sur la facturation

**Solution**:
1. Allez sur: https://console.cloud.google.com/billing
2. Liez un compte de facturation à votre projet
3. Re-lancez `./setup.sh`

### Problème 3: "API not enabled"

**Symptôme**: Erreur "API XYZ is not enabled"

**Solution**:
```bash
# Activer toutes les APIs nécessaires
gcloud services enable \\
  run.googleapis.com \\
  cloudbuild.googleapis.com \\
  aiplatform.googleapis.com
```

### Problème 4: Le micro ne marche pas

**Symptôme**: Pas de son, pas de reconnaissance

**Solution**:
- Utilisez Chrome ou Edge (meilleure compatibilité)
- Vérifiez que vous êtes en HTTPS (obligatoire pour le micro)
- Vérifiez les permissions dans les paramètres du navigateur
- Essayez de recharger la page

### Problème 5: "No module named 'X'"

**Symptôme**: Erreur Python lors de l'ingestion

**Solution**:
```bash
cd backend
pip install -r requirements.txt
```

---

## 📊 Voir les Logs

Si quelque chose ne marche pas:

```bash
# Voir les logs en temps réel
gcloud run logs tail multimodal-rag-inf1900

# Voir les derniers logs
gcloud run logs read multimodal-rag-inf1900 --limit=50
```

---

## 🎨 Personnalisation

### Changer le System Prompt

Éditez `backend/main.py` ligne 84:

```python
TA_SYSTEM_INSTRUCTION = """
Votre nouveau prompt ici...
"""
```

Puis re-déployez:
```bash
./setup.sh
```

### Ajouter des Sources

Éditez `backend/ingest.py` ligne 13:

```python
ENTRY_URL = "https://votre-nouveau-site.com/"
```

Puis:
```bash
python backend/ingest.py
./setup.sh
```

---

## 💰 Gérer les Coûts

### Voir les Coûts Actuels

1. Allez sur: https://console.cloud.google.com/billing
2. Sélectionnez votre projet
3. Consultez les coûts (devrait être 0$ pendant le workshop)

### Arrêter le Service (Pour Économiser)

Si vous voulez mettre en pause votre application:

```bash
gcloud run services update multimodal-rag-inf1900 \\
  --region=us-central1 \\
  --max-instances=0
```

Pour redémarrer:
```bash
gcloud run services update multimodal-rag-inf1900 \\
  --region=us-central1 \\
  --max-instances=10
```

### Supprimer Complètement

⚠️ Cela supprime TOUT (irreversible):

```bash
# Supprimer le service
gcloud run services delete multimodal-rag-inf1900 --region=us-central1

# Supprimer le projet (optionnel)
gcloud projects delete VOTRE-PROJECT-ID
```

---

## 🆘 Besoin d'Aide?

- 📧 Email: support@votre-org.com
- 💬 Slack: #workshop-rag
- 🙋 Pendant le workshop: Levez la main!

---

**Bon apprentissage! 🎓**
