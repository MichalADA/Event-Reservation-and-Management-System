const User = require('../models/postgres/User');
const jwt = require('jsonwebtoken');
const bcrypt = require('bcrypt');

class UserService {
  // Register user
  async register(userData) {
    try {
      // Check if user already exists
      const existingUser = await User.findOne({ where: { email: userData.email } });
      
      if (existingUser) {
        throw new Error('User with this email already exists');
      }

      // Create user
      const user = await User.create(userData);
      
      // Generate token
      const token = this.generateToken(user);
      
      return {
        user: {
          id: user.id,
          name: user.name,
          email: user.email,
          role: user.role
        },
        token
      };
    } catch (error) {
      throw new Error(`Registration failed: ${error.message}`);
    }
  }

  // Login user
  async login(email, password) {
    try {
      // Find user
      const user = await User.findOne({ where: { email } });
      
      if (!user) {
        throw new Error('User not found');
      }

      // Check password
      const isPasswordValid = await user.validPassword(password);
      
      if (!isPasswordValid) {
        throw new Error('Invalid password');
      }

      // Generate token
      const token = this.generateToken(user);
      
      return {
        user: {
          id: user.id,
          name: user.name,
          email: user.email,
          role: user.role
        },
        token
      };
    } catch (error) {
      throw new Error(`Login failed: ${error.message}`);
    }
  }

  // Get user profile
  async getUserProfile(userId) {
    try {
      const user = await User.findByPk(userId, {
        attributes: { exclude: ['password'] }
      });
      
      if (!user) {
        throw new Error('User not found');
      }
      
      return user;
    } catch (error) {
      throw new Error(`Could not fetch user profile: ${error.message}`);
    }
  }

  // Update user profile
  async updateUserProfile(userId, userData) {
    try {
      const user = await User.findByPk(userId);
      
      if (!user) {
        throw new Error('User not found');
      }

      // Update user data
      if (userData.name) user.name = userData.name;
      if (userData.email) user.email = userData.email;
      if (userData.phone) user.phone = userData.phone;
      if (userData.password) user.password = userData.password;

      await user.save();
      
      return {
        id: user.id,
        name: user.name,
        email: user.email,
        role: user.role,
        phone: user.phone
      };
    } catch (error) {
      throw new Error(`Could not update user profile: ${error.message}`);
    }
  }

  // Generate JWT token
  generateToken(user) {
    return jwt.sign(
      { id: user.id, email: user.email, role: user.role },
      process.env.JWT_SECRET || 'your_jwt_secret',
      { expiresIn: '24h' }
    );
  }
}

module.exports = new UserService();
