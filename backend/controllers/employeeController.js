import Employee from '../models/Employee.js';

// @desc    Get all employees
// @route   GET /api/employees
// @access  Public (for now)
export const getEmployees = async (req, res) => {
  try {
    const employees = await Employee.find({});
    res.json(employees);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

// @desc    Create an employee
// @route   POST /api/employees
// @access  Public (for now)
export const createEmployee = async (req, res) => {
  const { name, email, role, department } = req.body;

  try {
    const employeeExists = await Employee.findOne({ email });

    if (employeeExists) {
      return res.status(400).json({ message: 'Employee already exists' });
    }

    const employee = await Employee.create({
      name,
      email,
      role,
      department,
    });

    res.status(201).json(employee);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};
