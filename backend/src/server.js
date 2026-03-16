/**
 * AI Voice Translator - Node.js Server
 * Replaces Python/Flask backend with Express + Socket.IO
 * Supports 1-to-1 contact-based calls with live translation
 */

require('dotenv').config();
const express = require('express');
const http = require('http');
const { Server } = require('socket.io');
const cors = require('cors');
const mongoose = require('mongoose');
const rateLimit = require('express-rate-limit');
const path = require('path');

const { registerSocketHandlers } = require('./services/socketService');
const callsRouter = require('./routes/calls');
const translationRouter = require('./routes/translation');
const speechRouter = require('./routes/speech');
const ttsRouter = require('./routes/tts');
const messagesRouter = require('./routes/messages');
const usersRouter = require('./routes/users');
const aiRouter = require('./routes/ai');

// ─── App Setup ────────────────────────────────────────────────────────────────
const app = express();
const server = http.createServer(app);

const io = new Server(server, {
  cors: { origin: '*', methods: ['GET', 'POST'] },
  maxHttpBufferSize: 1e7, // 10MB for audio chunks
  pingTimeout: 60000,
  pingInterval: 25000,
});

// ─── Middleware ───────────────────────────────────────────────────────────────
app.use(cors({ origin: '*' }));
app.use(express.json({ limit: '50mb' }));
app.use(express.urlencoded({ extended: true, limit: '50mb' }));

const limiter = rateLimit({ windowMs: 15 * 60 * 1000, max: 500 });
app.use('/api/', limiter);

// ─── Routes ───────────────────────────────────────────────────────────────────
app.use('/api/calls', callsRouter);
app.use('/api/translation', translationRouter);
app.use('/api/speech', speechRouter);
app.use('/api/tts', ttsRouter);
app.use('/api/messages', messagesRouter);
app.use('/api/users', usersRouter);
app.use('/api/ai', aiRouter);

app.get('/', (req, res) => {
  res.send('<h1>🌐 AI Voice Translator Server is Running</h1><p>Use /health or /admin to check status.</p>');
});

// Health check
app.get('/health', (req, res) => {
  res.json({
    status: 'ok',
    service: 'AI Voice Translator Backend (Node.js)',
    version: '2.0.0',
    timestamp: new Date().toISOString(),
  });
});

// Admin dashboard (basic HTML)
app.get('/admin', async (req, res) => {
  try {
    const db = mongoose.connection.db;
    const usersCount = await db.collection('users').countDocuments();
    const callsCount = await db.collection('calllogs').countDocuments();
    const messagesCount = await db.collection('messages').countDocuments();
    const recentCalls = await db.collection('calllogs')
      .find({}).sort({ timestamp: -1 }).limit(10).toArray();

    res.send(`
      <!DOCTYPE html><html><head>
      <title>AI Voice Translator Admin</title>
      <style>body{font-family:sans-serif;background:#0f1117;color:#fff;padding:20px}
      .card{background:#1a1d27;border-radius:12px;padding:20px;margin:10px;display:inline-block;min-width:150px}
      .num{font-size:2em;font-weight:bold;color:#6C63FF}
      table{width:100%;border-collapse:collapse;margin-top:20px}
      td,th{padding:8px;border-bottom:1px solid #333;text-align:left}
      th{color:#6C63FF}</style></head><body>
      <h1>🌐 AI Voice Translator - Admin</h1>
      <div>
        <div class="card"><div class="num">${usersCount}</div>Users</div>
        <div class="card"><div class="num">${callsCount}</div>Calls</div>
        <div class="card"><div class="num">${messagesCount}</div>Messages</div>
      </div>
      <h2>Recent Calls</h2>
      <table><tr><th>Call ID</th><th>Caller</th><th>Receiver</th><th>Status</th><th>Time</th></tr>
      ${recentCalls.map(c => `<tr>
        <td>${c.callId?.substring(0,8)}...</td>
        <td>${c.callerId || '-'}</td>
        <td>${c.receiverId || '-'}</td>
        <td>${c.status}</td>
        <td>${c.timestamp}</td>
      </tr>`).join('')}
      </table></body></html>
    `);
  } catch (err) {
    res.status(500).send('Admin error: ' + err.message);
  }
});

// ─── Socket.IO ────────────────────────────────────────────────────────────────
registerSocketHandlers(io, mongoose.connection);

// ─── MongoDB Connection ───────────────────────────────────────────────────────
const connectDB = async () => {
  const mongoUri = process.env.MONGO_URI;
  
  try {
    console.log('⏳ Connecting to MongoDB...');
    // Try to connect with a 10-second timeout for server selection
    await mongoose.connect(mongoUri, {
      serverSelectionTimeoutMS: 10000,
    });
    console.log('✅ MongoDB connected (Atlas)');
    startServer();
  } catch (err) {
    console.error('❌ Atlas connection failed:', err.message);
    
    // Fallback to In-Memory MongoDB
    if (process.env.NODE_ENV === 'development') {
      try {
        console.log('⚠️  Attempting to start In-Memory MongoDB fallback...');
        const { MongoMemoryServer } = require('mongodb-memory-server');
        const mongod = await MongoMemoryServer.create();
        const uri = mongod.getUri();
        
        await mongoose.connect(uri);
        console.log('✅ SUCCESS: Connected to In-Memory MongoDB');
        console.log('📝 NOTE: Data will not persist between restarts.');
        startServer();
      } catch (innerErr) {
        console.error('❌ Critical: In-Memory MongoDB also failed:', innerErr.message);
        process.exit(1);
      }
    } else {
      process.exit(1);
    }
  }
};

const startServer = () => {
  const PORT = process.env.PORT || 5000;
  server.listen(PORT, '0.0.0.0', () => {
    console.log(`🚀 AI Voice Translator Backend running on port ${PORT}`);
    console.log(`📡 WebSocket ready`);
    console.log(`🔗 Health: http://localhost:${PORT}/health`);
    console.log(`🎛️  Admin:  http://localhost:${PORT}/admin`);
  });
};

connectDB();

module.exports = { app, server, io };
