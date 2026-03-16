const mongoose = require('mongoose');
const dns = require('dns');
require('dotenv').config();

// Attempt to use Google DNS to bypass local ISP/Router DNS issues
dns.setServers(['8.8.8.8', '8.8.4.4']);

// Fallback to legacy connection string (useful if SRV/DNS is blocked)
const legacyUri = "mongodb://suryaj:surya%40@cluster0-shard-00-00.w4s0i90.mongodb.net:27017,cluster0-shard-00-01.w4s0i90.mongodb.net:27017,cluster0-shard-00-02.w4s0i90.mongodb.net:27017/ai_voice_assistant?ssl=true&replicaSet=atlas-9utr-shard-0&authSource=admin&retryWrites=true&w=majority";

const uri = legacyUri;

console.log('--- MongoDB Connection Test (Legacy URI) ---');
console.log('URI:', uri.replace(/:([^@]+)@/, ':****@')); // Hide password

mongoose.connect(uri)
  .then(() => {
    console.log('✅ SUCCESS: Connected to MongoDB successfully!');
    process.exit(0);
  })
  .catch(err => {
    console.error('❌ FAILURE: Connection failed.');
    console.error('Error Name:', err.name);
    console.error('Error Message:', err.message);
    
    if (err.message.includes('ECONNREFUSED')) {
      console.log('\n--- Troubleshooting ---');
      console.log('1. Check your IP whitelist in MongoDB Atlas.');
      console.log('2. Ensure your firewall isn\'t blocking port 27017.');
      console.log('3. Try using a different DNS server (e.g., 8.8.8.8).');
    }
    process.exit(1);
  });
