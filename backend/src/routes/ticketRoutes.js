const express = require('express');
const ticketService = require('../services/ticketService');
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

// Zarezerwuj bilet
router.post('/reserve', authenticateToken, async (req, res) => {
  try {
    const { eventId, quantity } = req.body;
    const reservation = await ticketService.reserveTicket(req.user.id, eventId, quantity);
    res.status(201).json(reservation);
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
});

// Kup bilet
router.post('/purchase', authenticateToken, async (req, res) => {
  try {
    const { reservationId, paymentInfo } = req.body;
    const result = await ticketService.purchaseTicket(req.user.id, reservationId, paymentInfo);
    res.status(201).json(result);
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
});

// Pobierz bilety użytkownika
router.get('/my-tickets', authenticateToken, async (req, res) => {
  try {
    const tickets = await ticketService.getUserTickets(req.user.id);
    res.json(tickets);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Anuluj bilet
router.put('/:id/cancel', authenticateToken, async (req, res) => {
  try {
    const result = await ticketService.cancelTicket(req.user.id, req.params.id);
    res.json(result);
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
});

module.exports = router;
