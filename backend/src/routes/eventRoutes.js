const express = require('express');
const eventService = require('../services/eventService');
const Comment = require('../models/mongodb/Comment');
const Review = require('../models/mongodb/Review');
const Media = require('../models/mongodb/Media');
const multer = require('multer');
const path = require('path');
const fs = require('fs');
const jwt = require('jsonwebtoken');
const router = express.Router();

// Konfiguracja Multer dla przesyłania plików
const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    const dir = path.join(__dirname, '../../../uploads/events');
    if (!fs.existsSync(dir)) {
      fs.mkdirSync(dir, { recursive: true });
    }
    cb(null, dir);
  },
  filename: (req, file, cb) => {
    cb(null, `${Date.now()}-${file.originalname}`);
  }
});

const upload = multer({ storage });

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

// Middleware do sprawdzania roli organizatora
function isOrganizer(req, res, next) {
  if (req.user.role !== 'organizer' && req.user.role !== 'admin') {
    return res.status(403).json({ error: 'Access denied. Only organizers can perform this action' });
  }
  next();
}

// Pobierz wszystkie wydarzenia
router.get('/', async (req, res) => {
  try {
    const events = await eventService.getAllEvents(req.query);
    res.json(events);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Pobierz wydarzenie po ID
router.get('/:id', async (req, res) => {
  try {
    const event = await eventService.getEventById(req.params.id);
    res.json(event);
  } catch (error) {
    res.status(404).json({ error: error.message });
  }
});

// Utwórz nowe wydarzenie
router.post('/', authenticateToken, isOrganizer, async (req, res) => {
  try {
    const event = await eventService.createEvent(req.body, req.user.id);
    res.status(201).json(event);
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
});

// Zaktualizuj wydarzenie
router.put('/:id', authenticateToken, isOrganizer, async (req, res) => {
  try {
    const event = await eventService.updateEvent(req.params.id, req.body, req.user.id);
    res.json(event);
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
});

// Usuń wydarzenie
router.delete('/:id', authenticateToken, isOrganizer, async (req, res) => {
  try {
    const result = await eventService.deleteEvent(req.params.id, req.user.id);
    res.json(result);
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
});

// Pobierz komentarze do wydarzenia
router.get('/:id/comments', async (req, res) => {
  try {
    const comments = await Comment.find({ eventId: req.params.id }).sort({ createdAt: -1 });
    res.json(comments);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Dodaj komentarz do wydarzenia
router.post('/:id/comments', authenticateToken, async (req, res) => {
  try {
    const comment = new Comment({
      eventId: req.params.id,
      userId: req.user.id,
      userName: req.body.userName,
      text: req.body.text
    });
    
    await comment.save();
    res.status(201).json(comment);
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
});

// Pobierz recenzje wydarzenia
router.get('/:id/reviews', async (req, res) => {
  try {
    const reviews = await Review.find({ eventId: req.params.id }).sort({ createdAt: -1 });
    res.json(reviews);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Dodaj recenzję do wydarzenia
router.post('/:id/reviews', authenticateToken, async (req, res) => {
  try {
    // Sprawdź, czy użytkownik już dodał recenzję
    const existingReview = await Review.findOne({ 
      eventId: req.params.id,
      userId: req.user.id
    });
    
    if (existingReview) {
      return res.status(400).json({ error: 'You have already reviewed this event' });
    }
    
    const review = new Review({
      eventId: req.params.id,
      userId: req.user.id,
      userName: req.body.userName,
      rating: req.body.rating,
      title: req.body.title,
      text: req.body.text
    });
    
    await review.save();
    res.status(201).json(review);
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
});

// Dodaj zdjęcie/wideo do wydarzenia
router.post('/:id/media', authenticateToken, isOrganizer, upload.single('file'), async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ error: 'No file uploaded' });
    }
    
    const fileType = req.file.mimetype.startsWith('image/') ? 'image' : 'video';
    const media = new Media({
      eventId: req.params.id,
      type: fileType,
      url: `/uploads/events/${req.file.filename}`,
      caption: req.body.caption || '',
      uploadedBy: req.user.id
    });
    
    await media.save();
    res.status(201).json(media);
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
});

// Pobierz media wydarzenia
router.get('/:id/media', async (req, res) => {
  try {
    const media = await Media.find({ eventId: req.params.id }).sort({ createdAt: -1 });
    res.json(media);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

module.exports = router;
