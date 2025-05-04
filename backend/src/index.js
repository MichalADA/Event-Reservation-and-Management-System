const express = require('express');
const cors = require('cors');
const { sequelize, connectMongoDB, connectRedis } = require('./config/database');
const authRoutes = require('./routes/authRoutes');
const eventRoutes = require('./routes/eventRoutes');
const ticketRoutes = require('./routes/ticketRoutes');
const reviewRoutes = require('./routes/reviewRoutes');

// Inicjalizacja Express
const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Connect to databases
connectMongoDB();
connectRedis();

// PostgreSQL connection and sync models
sequelize.authenticate()
  .then(() => {
    console.log('PostgreSQL connected');
    return sequelize.sync({ force: false });
  })
  .then(() => console.log('PostgreSQL models synchronized'))
  .catch(err => console.error('PostgreSQL connection error:', err));

// Routes
app.use('/api/auth', authRoutes);
app.use('/api/events', eventRoutes);
app.use('/api/tickets', ticketRoutes);
app.use('/api/reviews', reviewRoutes);

// Base route
app.get('/', (req, res) => {
  res.json({ message: 'Event Management System API' });
});

// Start server
app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});
