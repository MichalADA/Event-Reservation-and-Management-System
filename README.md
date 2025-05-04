# Event Reservation and Management System - not working to be continued and debuged 

Not working so far problem with Mongo database in tests folder appears in future application performance tests
A comprehensive event reservation and management system utilizing various databases for optimal storage and processing of different data types.

## Project Description

The system enables event creation, ticket reservation and purchase, user management, and adding comments and reviews. The main functions of the system:

- User registration and login
- Creation and management of events by organizers
- Reservation and purchase of tickets by customers
- Adding comments and reviews to events
- Management of multimedia related to events
- Ticket cancellation and refunds

## Technologies

The project uses three different databases, each used for optimal storage of different data types:

- **PostgreSQL**: Structural data (users, events, tickets, payments)
- **MongoDB**: Flexible data (comments, reviews, photos)
- **Redis**: Cache and temporary data (reservations, seat availability)

Additionally, the system uses:
- **Node.js/Express**: Backend API
- **Docker & Docker Compose**: Containerization and orchestration

## Project Structure
```
.
├── docker-compose.yml
├── .env
├── test-event-system.sh
└── backend/
    ├── Dockerfile
    ├── package.json
    └── src/
        ├── index.js
        ├── config/
        │   └── database.js
        ├── models/
        │   ├── postgres/
        │   │   ├── User.js
        │   │   ├── Event.js
        │   │   ├── Ticket.js
        │   │   └── Payment.js
        │   └── mongodb/
        │       ├── Comment.js
        │       ├── Review.js
        │       └── Media.js
        ├── services/
        │   ├── eventService.js
        │   ├── ticketService.js
        │   └── userService.js
        └── routes/
            ├── authRoutes.js
            ├── eventRoutes.js
            ├── ticketRoutes.js
            └── reviewRoutes.js
```

## How the System Works

### Data Flow Between Databases

1. **PostgreSQL** stores all structural data that require relationships and referential integrity:
   - User data (table `Users`)
   - Event information (table `Events`)
   - Tickets (table `Tickets`)
   - Payments (table `Payments`)

2. **MongoDB** stores flexible data that can have variable structure:
   - User comments (collection `Comments`)
   - Event reviews (collection `Reviews`)
   - Media related to events (collection `Media`)

3. **Redis** stores temporary data and cache:
   - Event information cache (`event:{id}`)
   - Temporary ticket reservations (`reservation:{id}`)
   - Number of available seats (`event:{id}:seats`)

### Ticket Reservation and Purchase Process

1. **Ticket Reservation**:
   - Customer selects an event and number of tickets
   - System checks seat availability in PostgreSQL
   - Creates temporary reservation in Redis (valid for 10 minutes)
   - Temporarily reduces the number of available seats in Redis

2. **Ticket Purchase**:
   - Customer confirms reservation and makes payment
   - System retrieves reservation data from Redis
   - Creates ticket records in PostgreSQL
   - Creates payment record in PostgreSQL
   - Updates the number of available seats in PostgreSQL
   - Removes temporary reservation from Redis

3. **Ticket Cancellation**:
   - Customer cancels ticket
   - System updates ticket status in PostgreSQL
   - Increases the number of available seats in PostgreSQL
   - Updates available seats cache in Redis

### Integration of Comments and Reviews

1. **Adding a Comment**:
   - User adds a comment to an event
   - System saves the comment in MongoDB
   - Comment is immediately visible to other users

2. **Adding a Review**:
   - User adds an event review (with rating)
   - System saves the review in MongoDB
   - System checks if the user has already added a review

### Cache and Performance Optimization

1. **Event Data Cache**:
   - Event information is stored in Redis
   - For subsequent requests, the system first checks Redis
   - If data is not in cache, it retrieves it from PostgreSQL and updates the cache

2. **Number of Available Seats**:
   - Current number of available seats is stored in Redis
   - During reservation, the system creates a temporary record reducing available seats
   - After reservation expiration, seats are automatically released

## Installation and Running

### Requirements
- Docker
- Docker Compose

### Installation Steps

1. Clone the repository:
```
git clone https://github.com/your-username/event-reservation-system.git
cd event-reservation-system
```

2. Create `.env` file based on the example below:
```
NODE_ENV=development
MONGO_USER=admin
MONGO_PASSWORD=password
MONGO_URI=mongodb://mongodb:27017/eventsdb
POSTGRES_HOST=postgres
POSTGRES_DB=eventsdb
POSTGRES_USER=postgres_user
POSTGRES_PASSWORD=postgres_password
REDIS_HOST=redis
REDIS_PORT=6379
JWT_SECRET=your_jwt_secret_key_change_this_in_production
```

3. Build and run containers:
```
docker-compose up -d
```

4. Check if all services are running correctly:
```
docker-compose ps
```

5. Run the test script to test the system:
```
./test-event-system.sh
```

## Testing the System

The `test-event-system.sh` script conducts a full test of system functionality:

1. Organizer user registration
2. Regular user registration
3. Event creation by organizer
4. Retrieving event information
5. Adding comment to event
6. Retrieving event comments
7. Ticket reservation
8. Ticket purchase
9. Retrieving user tickets
10. Adding event review
11. Retrieving event reviews
12. Ticket cancellation

## API Endpoints

### Users and Authentication
- `POST /api/auth/register` - Register new user
- `POST /api/auth/login` - User login
- `GET /api/auth/profile` - Get user profile
- `PUT /api/auth/profile` - Update user profile

### Events
- `GET /api/events` - Get all events
- `GET /api/events/:id` - Get event details
- `POST /api/events` - Create new event (organizers only)
- `PUT /api/events/:id` - Update event (owner only)
- `DELETE /api/events/:id` - Delete event (owner only)

### Comments and Reviews
- `GET /api/events/:id/comments` - Get event comments
- `POST /api/events/:id/comments` - Add comment
- `GET /api/events/:id/reviews` - Get event reviews
- `POST /api/events/:id/reviews` - Add review
- `PUT /api/reviews/:id` - Update review (owner only)
- `DELETE /api/reviews/:id` - Delete review (owner only)

### Tickets
- `POST /api/tickets/reserve` - Reserve ticket
- `POST /api/tickets/purchase` - Purchase ticket
- `GET /api/tickets/my-tickets` - Get user tickets
- `PUT /api/tickets/:id/cancel` - Cancel ticket

### Media
- `POST /api/events/:id/media` - Add photo/video to event
- `GET /api/events/:id/media` - Get event media

## Data Models

### PostgreSQL

#### User
- id (UUID)
- name (String)
- email (String)
- password (String)
- role (Enum: admin, organizer, customer)
- phone (String)

#### Event
- id (UUID)
- title (String)
- description (Text)
- startDate (Date)
- endDate (Date)
- location (String)
- totalSeats (Integer)
- availableSeats (Integer)
- price (Decimal)
- category (String)
- isPublished (Boolean)
- organizerId (UUID, Foreign Key)

#### Ticket
- id (UUID)
- ticketNumber (String)
- seatNumber (String)
- price (Decimal)
- status (Enum: reserved, paid, cancelled)
- purchasedAt (Date)
- userId (UUID, Foreign Key)
- eventId (UUID, Foreign Key)

#### Payment
- id (UUID)
- amount (Decimal)
- paymentMethod (String)
- transactionId (String)
- status (Enum: pending, completed, failed, refunded)
- paymentDate (Date)
- userId (UUID, Foreign Key)
- ticketId (UUID, Foreign Key)

### MongoDB

#### Comment
- _id (ObjectId)
- eventId (String)
- userId (String)
- userName (String)
- text (String)
- createdAt (Date)
- updatedAt (Date)

#### Review
- _id (ObjectId)
- eventId (String)
- userId (String)
- userName (String)
- rating (Number, 1-5)
- title (String)
- text (String)
- createdAt (Date)

#### Media
- _id (ObjectId)
- eventId (String)
- type (Enum: image, video)
- url (String)
- caption (String)
- uploadedBy (String)
- createdAt (Date)

### Redis
- `event:{eventId}` - Event data cache
- `event:{eventId}:seats` - Event available seats cache
- `reservation:{reservationId}` - Temporary reservation (expires after 10 minutes)
- `event:{eventId}:temp_seats` - Temporary reduction of available seats during reservation

## Benefits of Using Multiple Databases

1. **PostgreSQL** - excellent for storing structural data:
   - Strong data integrity and ACID transactions
   - Relations and foreign keys ensure data consistency
   - Advanced SQL queries for complex operations

2. **MongoDB** - ideal for unstructured data:
   - Flexible schemas that can evolve without migrations
   - Faster writing of non-relational data like comments and reviews
   - Good performance for document read and write operations

3. **Redis** - optimal for temporary data and cache:
   - Very fast access to in-memory data
   - Automatic data expiration (TTL) ideal for reservations
   - Atomic operations on shared data (e.g., number of available seats)

## Development Plans

The system can be developed in many directions:

1. **Frontend** - user interface in React, Vue.js or Angular
2. **Event Search Engine** - advanced filters and search
3. **Payment Integrations** - Stripe, PayPal, BLIK
4. **Notification System** - email, SMS about upcoming events
5. **Reports and Analytics** - sales statistics, event popularity
6. **Subscriptions** - system of memberships and subscriptions for events

## License

MIT
