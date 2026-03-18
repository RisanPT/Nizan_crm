import Booking from '../models/Booking.js';
import Customer from '../models/Customer.js';

export const getBookings = async (req, res) => {
  try {
    const bookings = await Booking.find({});
    res.json(bookings);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

export const createBooking = async (req, res) => {
  const { customerName, phone, email, service, region, bookingDate, serviceStart, serviceEnd, totalPrice, advanceAmount } = req.body;

  try {
    // Try to find an existing customer by email OR phone
    const query = [];
    if (email) query.push({ email });
    if (phone) query.push({ phone });

    const customerExists = query.length > 0
      ? await Customer.findOne({ $or: query })
      : null;

    if (!customerExists) {
      // Auto-create customer. Use a placeholder email if none was given
      // (email is required + unique in the schema).
      await Customer.create({
        name: customerName,
        email: email || `${phone}@placeholder.local`,
        phone,
        status: 'Active',
      });
    }

    const booking = await Booking.create({
      customerName,
      email,
      phone,
      service,
      region,
      bookingDate,
      serviceStart,
      serviceEnd,
      totalPrice,
      advanceAmount,
    });

    res.status(201).json(booking);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

export const deleteBooking = async (req, res) => {
  try {
    const booking = await Booking.findById(req.params.id);

    if (booking) {
      await booking.deleteOne();
      res.json({ message: 'Booking removed' });
    } else {
      res.status(404).json({ message: 'Booking not found' });
    }
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};
