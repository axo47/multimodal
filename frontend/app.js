// Configuration
let BACKEND_URL = "https://multimodal-rag-inf1900-zhalipgtaq-uc.a.run.app";

// Éléments DOM
const chatBox = document.getElementById('chat-box');
const textInput = document.getElementById('text-input');
const sendBtn = document.getElementById('send-btn');
const uploadBtn = document.getElementById('upload-btn');
const uploadAudioBtn = document.getElementById('upload-audio-btn');
const generateBtn = document.getElementById('generate-btn');
const fileInput = document.getElementById('file-input');
const audioInput = document.getElementById('audio-input');
const statusDiv = document.getElementById('status');

// Charger la config du backend
async function loadConfig() {
    try {
        const response = await fetch('/config');
        const config = await response.json();
        BACKEND_URL = config.backend_url;
        console.log('Backend URL:', BACKEND_URL);
    } catch (error) {
        console.log('Using default backend URL:', BACKEND_URL);
    }
}

// Ajouter un message au chat
function addMessage(role, content, imageData = null, ragUsed = false) {
    const messageDiv = document.createElement('div');
    messageDiv.className = `message ${role}`;
    
    const roleDiv = document.createElement('div');
    roleDiv.className = 'role';
    roleDiv.textContent = role === 'user' ? '👤 Vous' : '🤖 Assistant';
    
    // Badge RAG
    if (ragUsed && role === 'assistant') {
        const ragBadge = document.createElement('span');
        ragBadge.textContent = ' 📚 RAG';
        ragBadge.style.cssText = 'background: #4CAF50; color: white; padding: 2px 8px; border-radius: 10px; font-size: 0.8em; margin-left: 10px;';
        roleDiv.appendChild(ragBadge);
    }
    
    const contentDiv = document.createElement('div');
    contentDiv.innerHTML = content.replace(/\n/g, '<br>');
    
    messageDiv.appendChild(roleDiv);
    messageDiv.appendChild(contentDiv);
    
    if (imageData) {
        const img = document.createElement('img');
        img.src = `data:image/png;base64,${imageData}`;
        img.alt = 'Image générée';
        messageDiv.appendChild(img);
    }
    
    chatBox.appendChild(messageDiv);
    chatBox.scrollTop = chatBox.scrollHeight;
}

// Mettre à jour le statut
function updateStatus(text, className = '') {
    statusDiv.textContent = text;
    statusDiv.className = `status ${className}`;
}

// Envoyer un message texte
async function sendTextMessage(message) {
    if (!message.trim()) return;
    
    addMessage('user', message);
    textInput.value = '';
    sendBtn.disabled = true;
    updateStatus('⏳ Recherche dans la doc...', 'connecting');
    
    try {
        const response = await fetch(`${BACKEND_URL}/query`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({
                query: message
            })
        });
        
        if (!response.ok) {
            const errorText = await response.text();
            throw new Error(`HTTP ${response.status}: ${errorText}`);
        }
        
        const data = await response.json();
        const answer = data.answer || data.response || 'Pas de réponse';
        const ragUsed = data.has_context || data.rag_used;
        
        addMessage('assistant', answer, null, ragUsed);
        updateStatus('📡 Prêt', '');
        
    } catch (error) {
        console.error('Erreur envoi message:', error);
        addMessage('assistant', `❌ Erreur de connexion.\n\nDétails: ${error.message}`);
        updateStatus('❌ Erreur', 'disconnected');
    } finally {
        sendBtn.disabled = false;
    }
}

// Upload d'image
async function uploadImage(file) {
    if (!file) return;
    
    try {
        updateStatus('📤 Analyse avec Vision + RAG...', 'connecting');
        addMessage('user', '📷 [Image partagée]');
        
        const reader = new FileReader();
        reader.onload = async (e) => {
            const base64Image = e.target.result.split(',')[1];
            
            try {
                const response = await fetch(`${BACKEND_URL}/upload-image`, {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json',
                    },
                    body: JSON.stringify({
                        image: base64Image,
                        mimeType: file.type || 'image/jpeg'
                    })
                });
                
                if (!response.ok) {
                    const errorText = await response.text();
                    throw new Error(`HTTP ${response.status}: ${errorText}`);
                }
                
                const data = await response.json();
                const answer = data.response || data.answer || 'Image analysée!';
                const ragUsed = data.has_context || data.rag_used;
                
                addMessage('assistant', answer, null, ragUsed);
                updateStatus('📡 Prêt', '');
                
            } catch (error) {
                console.error('Erreur upload:', error);
                addMessage('assistant', `❌ Erreur lors de l'envoi\n\nDétails: ${error.message}`);
                updateStatus('❌ Erreur', 'disconnected');
            }
        };
        
        reader.onerror = () => {
            addMessage('assistant', '❌ Erreur lecture fichier');
            updateStatus('❌ Erreur', 'disconnected');
        };
        
        reader.readAsDataURL(file);
        
    } catch (error) {
        console.error('Erreur upload:', error);
        addMessage('assistant', `❌ Erreur: ${error.message}`);
        updateStatus('❌ Erreur', 'disconnected');
    }
}

// 🎵 Upload fichier audio (comme upload image!)
async function uploadAudioFile(file) {
    if (!file) return;
    
    try {
        updateStatus('📤 Envoi de l\'audio...', 'connecting');
        addMessage('user', `🎵 [Fichier audio: ${file.name}]`);
        
        const reader = new FileReader();
        reader.onload = async (e) => {
            const base64Audio = e.target.result.split(',')[1];
            
            try {
                updateStatus('🎤 Transcription + RAG...', 'connecting');
                
                const response = await fetch(`${BACKEND_URL}/upload-audio`, {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json',
                    },
                    body: JSON.stringify({
                        audio: base64Audio,
                        mimeType: file.type || 'audio/mpeg'
                    })
                });
                
                if (!response.ok) {
                    const errorText = await response.text();
                    throw new Error(`HTTP ${response.status}: ${errorText}`);
                }
                
                const data = await response.json();
                
                // Afficher transcription
                addMessage('user', `📝 Transcription: "${data.transcription}"`);
                
                // Afficher réponse avec badge RAG
                const ragUsed = data.has_context || data.rag_used;
                addMessage('assistant', data.answer, null, ragUsed);
                
                updateStatus('📡 Prêt', '');
                
            } catch (error) {
                console.error('Erreur upload audio:', error);
                addMessage('assistant', `❌ Erreur transcription\n\nDétails: ${error.message}`);
                updateStatus('❌ Erreur', 'disconnected');
            }
        };
        
        reader.onerror = () => {
            addMessage('assistant', '❌ Erreur lecture fichier audio');
            updateStatus('❌ Erreur', 'disconnected');
        };
        
        reader.readAsDataURL(file);
        
    } catch (error) {
        console.error('Erreur upload audio:', error);
        addMessage('assistant', `❌ Erreur: ${error.message}`);
        updateStatus('❌ Erreur', 'disconnected');
    }
}

// Générer une image
async function generateImage() {
    const prompt = window.prompt('🎨 Décrivez l\'image:\n\nExemple: "Schéma du registre PORTD"\n\nPrompt:');
    
    if (!prompt || !prompt.trim()) {
        return;
    }
    
    addMessage('user', `🎨 Génère : "${prompt}"`);
    updateStatus('🎨 RAG enrichit le prompt...', 'connecting');
    generateBtn.disabled = true;
    
    try {
        const response = await fetch(`${BACKEND_URL}/generate-image`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({
                prompt: prompt,
                number_of_images: 1
            })
        });
        
        if (!response.ok) {
            const errorText = await response.text();
            throw new Error(`HTTP ${response.status}: ${errorText}`);
        }
        
        const data = await response.json();
        
        if (data.success && data.image) {
            const ragUsed = data.enhanced || data.rag_used;
            const message = ragUsed 
                ? `✅ Image générée avec RAG : "${prompt}"` 
                : `✅ Image générée : "${prompt}"`;
            addMessage('assistant', message, data.image, ragUsed);
            updateStatus('📡 Prêt', '');
        } else {
            throw new Error('Pas d\'image dans la réponse');
        }
        
    } catch (error) {
        console.error('Erreur génération:', error);
        
        if (error.message.includes('503')) {
            addMessage('assistant', `⚠️ Génération d'images indisponible.\n\nVous pouvez:\n• Poser des questions\n• Analyser des images\n• 🎵 Upload fichier audio`);
        } else {
            addMessage('assistant', `❌ Erreur génération\n\nDétails: ${error.message}`);
        }
        
        updateStatus('❌ Erreur', 'disconnected');
    } finally {
        generateBtn.disabled = false;
    }
}

// Event listeners
sendBtn.addEventListener('click', () => {
    const message = textInput.value.trim();
    if (message) {
        sendTextMessage(message);
    }
});

textInput.addEventListener('keypress', (e) => {
    if (e.key === 'Enter') {
        const message = textInput.value.trim();
        if (message) {
            sendTextMessage(message);
        }
    }
});

uploadBtn.addEventListener('click', () => fileInput.click());
uploadAudioBtn.addEventListener('click', () => audioInput.click());
generateBtn.addEventListener('click', generateImage);

fileInput.addEventListener('change', (e) => {
    if (e.target.files && e.target.files.length > 0) {
        uploadImage(e.target.files[0]);
        e.target.value = '';
    }
});

audioInput.addEventListener('change', (e) => {
    if (e.target.files && e.target.files.length > 0) {
        uploadAudioFile(e.target.files[0]);
        e.target.value = '';
    }
});

// Charger la config au démarrage
loadConfig();

// Message de bienvenue
setTimeout(() => {
    addMessage('assistant', 'Bonjour! 👋\n\nJe suis votre assistant RAG multimodal pour INF1900.\n\n🔥 TOUS mes modes utilisent le RAG:\n• 💬 Questions: Recherche dans la doc\n• 📷 Images: Vision + doc\n• 🎨 Génération: Prompts enrichis\n• 🎵 Audio: Drop fichier → Transcription + doc\n\nComment puis-je vous aider?');
}, 500);