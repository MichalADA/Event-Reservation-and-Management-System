const Event = require('../models/postgres/Event');
const { redisClient } = require('../config/database');
const Media = require('../models/mongodb/Media');
const Review = require('../models/mongodb/Review');
const Comment = require('../models/mongodb/Comment');

class EventService {
  // Create a new event
  async createEvent(eventData, organizerId) {
    try {
      const event = await Event.create({
        ...eventData,
        organizerId,
        availableSeats: eventData.totalSeats
      });

      // Cache event data in Redis
      await redisClient.set(`event:${event.id}`, JSON.stringify(event));
      
      return event;
    } catch (error) {
      throw new Error(`Could not create event: ${error.message}`);
    }
  }

  // Get all events
  async getAllEvents(filters = {}) {
    try {
      const events = await Event.findAll({
        where: { ...filters, isPublished: true }
      });
      return events;
    } catch (error) {
      throw new Error(`Could not fetch events: ${error.message}`);
    }
  }

  // Get event by ID
  async getEventById(eventId) {
    try {
      // Try to get from cache first
      const cachedEvent = await redisClient.get(`event:${eventId}`);
      
      if (cachedEvent) {
        return JSON.parse(cachedEvent);
      }

      // If not in cache, get from database
      const event = await Event.findByPk(eventId);
      
      if (!event) {
        throw new Error('Event not found');
      }

      // Store in cache
      await redisClient.set(`event:${eventId}`, JSON.stringify(event));
      
      return event;
    } catch (error) {
      throw new Error(`Could not fetch event: ${error.message}`);
    }
  }

  // Update event
  async updateEvent(eventId, eventData, organizerId) {
    try {
      const event = await Event.findOne({
        where: { id: eventId, organizerId }
      });
      
      if (!event) {
        throw new Error('Event not found or you are not authorized');
      }

      await event.update(eventData);

      // Update cache
      await redisClient.set(`event:${eventId}`, JSON.stringify(event));
      
      return event;
    } catch (error) {
      throw new Error(`Could not update event: ${error.message}`);
    }
  }

  // Delete event
  async deleteEvent(eventId, organizerId) {
    try {
      const event = await Event.findOne({
        where: { id: eventId, organizerId }
      });
      
      if (!event) {
        throw new Error('Event not found or you are not authorized');
      }

      // Delete related MongoDB documents
      await Media.deleteMany({ eventId });
      await Review.deleteMany({ eventId });
      await Comment.deleteMany({ eventId });

      // Delete from Redis cache
      await redisClient.del(`event:${eventId}`);
      
      // Delete the event
      await event.destroy();
      
      return { message: 'Event deleted successfully' };
    } catch (error) {
      throw new Error(`Could not delete event: ${error.message}`);
    }
  }

  // Get available seats
  async getAvailableSeats(eventId) {
    try {
      // Try to get from cache first
      const cachedSeats = await redisClient.get(`event:${eventId}:seats`);
      
      if (cachedSeats) {
        return parseInt(cachedSeats);
      }

      // If not in cache, get from database
      const event = await Event.findByPk(eventId);
      
      if (!event) {
        throw new Error('Event not found');
      }

      // Store in cache
      await redisClient.set(`event:${eventId}:seats`, event.availableSeats.toString());
      
      return event.availableSeats;
    } catch (error) {
      throw new Error(`Could not get available seats: ${error.message}`);
    }
  }

  // Update available seats
  async updateAvailableSeats(eventId, count) {
    try {
      const event = await Event.findByPk(eventId);
      
      if (!event) {
        throw new Error('Event not found');
      }

      if (event.availableSeats - count < 0) {
        throw new Error('Not enough available seats');
      }

      event.availableSeats -= count;
      await event.save();

      // Update cache
      await redisClient.set(`event:${eventId}:seats`, event.availableSeats.toString());
      
      return event.availableSeats;
    } catch (error) {
      throw new Error(`Could not update available seats: ${error.message}`);
    }
  }
}

module.exports = new EventService();
