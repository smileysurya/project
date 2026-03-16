/**
 * Users REST route
 */
const express = require('express');
const router = express.Router();
const { User } = require('../models');

// POST /api/users/register
router.post('/register', async (req, res) => {
  try {
    const { userId, name, email, phone, language } = req.body;
    if (!userId || !name) return res.status(400).json({ error: 'userId and name required' });

    const user = await User.findOneAndUpdate(
      { userId },
      { name, email: email || '', phone: phone || '', language: language || 'en', updatedAt: new Date() },
      { upsert: true, new: true }
    );
    res.json({ success: true, user });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// GET /api/users/:userId
router.get('/:userId', async (req, res) => {
  try {
    const user = await User.findOne({ userId: req.params.userId }).lean();
    if (!user) return res.status(404).json({ error: 'User not found' });
    res.json({ success: true, user });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// GET /api/users/:userId/online
router.get('/:userId/online', async (req, res) => {
  try {
    const user = await User.findOne({ userId: req.params.userId }, { isOnline: 1 }).lean();
    res.json({ success: true, isOnline: user?.isOnline || false });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

module.exports = router;
