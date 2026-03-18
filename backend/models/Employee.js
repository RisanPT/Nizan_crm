import mongoose from 'mongoose';

const employeeSchema = mongoose.Schema(
  {
    name: {
      type: String,
      required: [true, 'Please add a name'],
    },
    email: {
      type: String,
      required: [true, 'Please add an email'],
      unique: true,
    },
    role: {
      type: String,
      required: [true, 'Please add a role'],
      default: 'Employee',
    },
    department: {
      type: String,
      required: [true, 'Please add a department'],
    },
  },
  {
    timestamps: true,
  }
);

const Employee = mongoose.model('Employee', employeeSchema);

export default Employee;
