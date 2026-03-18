import express from 'express';
import dotenv from 'dotenv';
import cors from 'cors';
import connectDB from './config/db.js';
import employeeRoutes from './routes/employeeRoutes.js';
import customerRoutes from './routes/customerRoutes.js';
import leadRoutes from './routes/leadRoutes.js';
import attendanceRoutes from './routes/attendanceRoutes.js';
import bookingRoutes from './routes/bookingRoutes.js';

dotenv.config();

// Connect to MongoDB
// Only connect if URI is provided, otherwise skip to prevent crashing while setting up
if (process.env.MONGO_URI && process.env.MONGO_URI !== 'your_mongodb_connection_string_here') {
  connectDB();
} else {
  console.log('MongoDB connection skipped: Please provide a valid MONGO_URI in the .env file');
}

const app = express();

// Middleware
app.use(cors());
app.use(express.json());

// Routes
app.use('/api/employees', employeeRoutes);
app.use('/api/customers', customerRoutes);
app.use('/api/leads', leadRoutes);
app.use('/api/attendances', attendanceRoutes);
app.use('/api/bookings', bookingRoutes);

app.get('/', (req, res) => {
  res.send('API is running...');
});

const PORT = process.env.PORT || 5000;

app.listen(PORT, () => console.log(`Server running on port ${PORT}`));
