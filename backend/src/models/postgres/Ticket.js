const { DataTypes } = require('sequelize');
const { sequelize } = require('../../config/database');
const User = require('./User');
const Event = require('./Event');

const Ticket = sequelize.define('Ticket', {
  id: {
    type: DataTypes.UUID,
    defaultValue: DataTypes.UUIDV4,
    primaryKey: true
  },
  ticketNumber: {
    type: DataTypes.STRING,
    allowNull: false,
    unique: true
  },
  seatNumber: {
    type: DataTypes.STRING,
    allowNull: true
  },
  price: {
    type: DataTypes.DECIMAL(10, 2),
    allowNull: false
  },
  status: {
    type: DataTypes.ENUM('reserved', 'paid', 'cancelled'),
    defaultValue: 'reserved'
  },
  purchasedAt: {
    type: DataTypes.DATE,
    allowNull: true
  }
}, {
  timestamps: true
});

// Relacje
Ticket.belongsTo(User, { foreignKey: 'userId' });
Ticket.belongsTo(Event, { foreignKey: 'eventId' });

module.exports = Ticket;
