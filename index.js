const makeWASocket = require("@whiskeysockets/baileys").default;
const {
    useSingleFileAuthState,
    DisconnectReason,
    fetchLatestBaileysVersion,
} = require("@whiskeysockets/baileys");

const { Boom } = require("@hapi/boom");
const qrcode = require("qrcode-terminal");
const axios = require("axios");
require("dotenv").config();

const { state, saveState } = useSingleFileAuthState("./auth.json");

async function startSock() {
    const { version } = await fetchLatestBaileysVersion();
    const sock = makeWASocket({
        version,
        printQRInTerminal: true,
        auth: state,
    });

    sock.ev.on("creds.update", saveState);

    sock.ev.on("connection.update", ({ connection, lastDisconnect }) => {
        if (connection === "close") {
            const shouldReconnect =
                (lastDisconnect?.error)?.output?.statusCode !== DisconnectReason.loggedOut;
            console.log("Koneksi terputus, mencoba ulang:", shouldReconnect);
            if (shouldReconnect) {
                startSock();
            }
        } else if (connection === "open") {
            console.log("✅ Terhubung ke WhatsApp!");
        }
    });

    sock.ev.on("messages.upsert", async ({ messages }) => {
        const msg = messages[0];
        if (!msg.message || msg.key.fromMe) return;

        const sender = msg.key.remoteJid;
        const text = msg.message.conversation || msg.message.extendedTextMessage?.text || "";

        console.log("📩 Pesan diterima:", text);

        // Balas pakai AI
        try {
            const res = await axios.post(`${process.env.API_URL}/chat`, {
                message: text,
            });
            await sock.sendMessage(sender, { text: res.data.reply });
        } catch (err) {
            await sock.sendMessage(sender, {
                text: "⚠️ Gagal membalas pesan.",
            });
        }
    });
}

startSock();
