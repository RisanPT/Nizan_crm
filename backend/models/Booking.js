import mongoose from 'mongoose';

const bookingSchema = mongoose.Schema(
  {
    customerName: {
      type: String,
      required: true,
    },
    email: {
      type: String,
    },
    phone: {
      type: String,
    },
    service: {
      type: String,
      required: true,
    },
    region: {
      type: String,
    },
    bookingDate: {
      type: Date,
      required: true,
    },
    serviceStart: {
      type: Date,
      required: true,
    },
    serviceEnd: {
      type: Date,
      required: true,
    },
    totalPrice: {
      type: Number,
      required: true,
    },
    advanceAmount: {
      type: Number,
      default: 0,
    },
  },
  {
    timestamps: true,
  }
);

const Booking = mongoose.model('Booking', bookingSchema);

export default Booking;
