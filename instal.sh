#!/bin/bash
# Auto Installer: WhatsApp Bot AI (Flask + Node.js + VENV)

echo "🚀 Memulai instalasi bot WhatsApp AI..."

# Install dependencies
sudo apt update && sudo apt install -y nodejs npm python3 python3-pip python3-venv git curl
sudo npm install -g pm2

# Buat folder project
mkdir -p ~/wa-bot-ai && cd ~/wa-bot-ai

# Buat virtual environment
python3 -m venv venv
source venv/bin/activate

# Buat requirements.txt dan install Python deps
cat > requirements.txt <<EOF
flask
openai
python-dotenv
EOF

pip install -r requirements.txt

# Buat file .env
cat > .env <<EOF
OPENAI_API_KEY=
EOF

# Buat app.py
cat > app.py <<'EOF'
from flask import Flask, request, jsonify
import openai
import os
from dotenv import load_dotenv

load_dotenv()
openai.api_key = os.getenv("OPENAI_API_KEY")

app = Flask(__name__)

@app.route("/chat", methods=["POST"])
def chat():
    data = request.json
    message = data.get("message", "")
    if not message:
        return jsonify({"reply": "Pesan kosong."})

    try:
        response = openai.ChatCompletion.create(
            model="gpt-3.5-turbo",
            messages=[{ "role": "user", "content": message }]
        )
        reply = response["choices"][0]["message"]["content"].strip()
        return jsonify({"reply": reply})
    except Exception as e:
        return jsonify({"reply": f"Error: {str(e)}"})

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
EOF

# Install Node.js dependencies
npm init -y
npm install dotenv @adiwajshing/baileys axios @hapi/boom

# Buat index.js
cat > index.js <<'EOF'
require("dotenv").config();
const { default: makeWASocket, useSingleFileAuthState } = require("@adiwajshing/baileys");
const axios = require("axios");
const { Boom } = require("@hapi/boom");
const { state, saveState } = useSingleFileAuthState("./auth.json");

async function connectBot() {
    const sock = makeWASocket({ auth: state });
    sock.ev.on("creds.update", saveState);

    sock.ev.on("messages.upsert", async ({ messages, type }) => {
        if (type !== "notify") return;
        const m = messages[0];
        if (!m.message || m.key.fromMe) return;

        const text = m.message.conversation || m.message.extendedTextMessage?.text;
        const from = m.key.remoteJid;

        console.log(`📩 ${from}: ${text}`);

        try {
            const res = await axios.post("http://localhost:5000/chat", { message: text });
            const reply = res.data.reply;
            await sock.sendMessage(from, { text: reply });
        } catch (err) {
            console.error("❌ Gagal balas:", err.message);
        }
    });
}

connectBot();
EOF

# Info selanjutnya
echo ""
echo "✅ Instalasi selesai!"
echo "📌 Jalankan Flask (Python):"
echo "   cd ~/wa-bot-ai && source venv/bin/activate && python app.py"
echo ""
echo "📌 Jalankan WhatsApp bot:"
echo "   cd ~/wa-bot-ai && node index.js"
echo ""
echo "⚠️  Ubah API key di file .env sebelum dijalankan."
