const { DataTypes } = require('sequelize');
const { sequelize } = require('../../config/database');
const User = require('./User');
const Ticket = require('./Ticket');

const Payment = sequelize.define('Payment', {
  id: {
    type: DataTypes.UUID,
    defaultValue: DataTypes.UUIDV4,
    primaryKey: true
  },
  amount: {
    type: DataTypes.DECIMAL(10, 2),
    allowNull: false
  },
  paymentMethod: {
    type: DataTypes.STRING,
    allowNull: false
  },
  transactionId: {
    type: DataTypes.STRING,
    allowNull: true
  },
  status: {
    type: DataTypes.ENUM('pending', 'completed', 'failed', 'refunded'),
    defaultValue: 'pending'
  },
  paymentDate: {
    type: DataTypes.DATE,
    defaultValue: DataTypes.NOW
  }
}, {
  timestamps: true
});

// Relacje
Payment.belongsTo(User, { foreignKey: 'userId' });
Payment.belongsTo(Ticket, { foreignKey: 'ticketId' });

module.exports = Payment;
