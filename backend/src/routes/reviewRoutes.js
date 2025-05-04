const express = require('express');
const Review = require('../models/mongodb/Review');
const jwt = require('jsonwebtoken');
const router = express.Router();

// Middleware do autentykacji
function authenticateToken(req, res, next) {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];
  
  if (!token) {
    return res.status(401).json({ error: 'Access token required' });
  }
  
  jwt.verify(token, process.env.JWT_SECRET || 'your_jwt_secret', (err, user) => {
    if (err) {
      return res.status(403).json({ error: 'Invalid or expired token' });
    }
    req.user = user;
    next();
  });
}

// Pobierz wszystkie recenzje
router.get('/', async (req, res) => {
  try {
    const reviews = await Review.find().sort({ createdAt: -1 });
    res.json(reviews);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Pobierz recenzję po ID
router.get('/:id', async (req, res) => {
  try {
    const review = await Review.findById(req.params.id);
    if (!review) {
      return res.status(404).json({ error: 'Review not found' });
    }
    res.json(review);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Zaktualizuj recenzję
router.put('/:id', authenticateToken, async (req, res) => {
  try {
    const review = await Review.findOne({
      _id: req.params.id,
      userId: req.user.id
    });
    
    if (!review) {
      return res.status(404).json({ error: 'Review not found or you are not authorized' });
    }
    
    if (req.body.rating) review.rating = req.body.rating;
    if (req.body.title) review.title = req.body.title;
    if (req.body.text) review.text = req.body.text;
    review.updatedAt = new Date();
    
    await review.save();
    res.json(review);
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
});

// Usuń recenzję
router.delete('/:id', authenticateToken, async (req, res) => {
  try {
    const review = await Review.findOne({
      _id: req.params.id,
      userId: req.user.id
    });
    
    if (!review) {
      return res.status(404).json({ error: 'Review not found or you are not authorized' });
    }
    
    await review.deleteOne();
    res.json({ message: 'Review deleted successfully' });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

module.exports = router;
