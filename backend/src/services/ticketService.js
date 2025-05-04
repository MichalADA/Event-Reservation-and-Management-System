const Ticket = require('../models/postgres/Ticket');
const Event = require('../models/postgres/Event');
const Payment = require('../models/postgres/Payment');
const { redisClient } = require('../config/database');
const eventService = require('./eventService');
const { v4: uuidv4 } = require('uuid');

class TicketService {
  // Reserve tickets
  async reserveTicket(userId, eventId, quantity = 1) {
    try {
      // Check if event exists and has enough seats
      const availableSeats = await eventService.getAvailableSeats(eventId);
      
      if (availableSeats < quantity) {
        throw new Error('Not enough available seats');
      }

      // Get event details
      const event = await Event.findByPk(eventId);
      
      if (!event) {
        throw new Error('Event not found');
      }

      // Create reservation in Redis (expires in 10 minutes)
      const reservationId = uuidv4();
      const reservation = {
        userId,
        eventId,
        quantity,
        price: event.price * quantity,
        createdAt: new Date().toISOString()
      };

      await redisClient.set(`reservation:${reservationId}`, JSON.stringify(reservation), {
        EX: 600 // 10 minutes
      });

      // Temporarily decrease available seats in Redis
      await redisClient.set(`event:${eventId}:temp_seats`, (availableSeats - quantity).toString(), {
        EX: 600 // 10 minutes
      });

      return {
        reservationId,
        ...reservation,
        expiresIn: '10 minutes'
      };
    } catch (error) {
      throw new Error(`Could not reserve ticket: ${error.message}`);
    }
  }

  // Confirm and purchase tickets
  async purchaseTicket(userId, reservationId, paymentInfo) {
    try {
      // Get reservation from Redis
      const reservationData = await redisClient.get(`reservation:${reservationId}`);
      
      if (!reservationData) {
        throw new Error('Reservation expired or not found');
      }

      const reservation = JSON.parse(reservationData);
      
      if (reservation.userId !== userId) {
        throw new Error('Unauthorized');
      }

      // Update available seats in the database
      await eventService.updateAvailableSeats(reservation.eventId, reservation.quantity);

      // Generate tickets
      const tickets = [];
      for (let i = 0; i < reservation.quantity; i++) {
        const ticket = await Ticket.create({
          userId,
          eventId: reservation.eventId,
          ticketNumber: `TIX-${uuidv4().substring(0, 8)}`,
          price: reservation.price / reservation.quantity,
          status: 'paid',
          purchasedAt: new Date()
        });

        tickets.push(ticket);
      }

      // Create payment record
      const payment = await Payment.create({
        userId,
        ticketId: tickets[0].id, // Link to the first ticket for simplicity
        amount: reservation.price,
        paymentMethod: paymentInfo.method,
        transactionId: paymentInfo.transactionId || `TRX-${uuidv4().substring(0, 8)}`,
        status: 'completed'
      });

      // Clean up Redis
      await redisClient.del(`reservation:${reservationId}`);
      await redisClient.del(`event:${reservation.eventId}:temp_seats`);
      
      return {
        tickets,
        payment
      };
    } catch (error) {
      throw new Error(`Could not purchase ticket: ${error.message}`);
    }
  }

  // Get user tickets
  async getUserTickets(userId) {
    try {
      const tickets = await Ticket.findAll({
        where: { userId },
        include: [Event],
        order: [['createdAt', 'DESC']]
      });
      
      return tickets;
    } catch (error) {
      throw new Error(`Could not fetch tickets: ${error.message}`);
    }
  }

  // Cancel ticket
  async cancelTicket(userId, ticketId) {
    try {
      const ticket = await Ticket.findOne({
        where: { id: ticketId, userId }
      });
      
      if (!ticket) {
        throw new Error('Ticket not found or you are not authorized');
      }

      if (ticket.status === 'cancelled') {
        throw new Error('Ticket is already cancelled');
      }

      // Check if event is in the future
      const event = await Event.findByPk(ticket.eventId);
      
      if (new Date(event.startDate) < new Date()) {
        throw new Error('Cannot cancel ticket for past events');
      }

      // Update ticket status
      ticket.status = 'cancelled';
      await ticket.save();

      // Update available seats
      event.availableSeats += 1;
      await event.save();

      // Update cache
      await redisClient.set(`event:${event.id}:seats`, event.availableSeats.toString());
      
      return {
        message: 'Ticket cancelled successfully',
        ticket
      };
    } catch (error) {
      throw new Error(`Could not cancel ticket: ${error.message}`);
    }
  }
}

module.exports = new TicketService();
