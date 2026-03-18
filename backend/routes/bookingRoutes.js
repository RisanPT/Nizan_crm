import express from 'express';
import { getBookings, createBooking, deleteBooking } from '../controllers/bookingController.js';

const router = express.Router();

router.route('/').get(getBookings).post(createBooking);
router.route('/:id').delete(deleteBooking);

export default router;
