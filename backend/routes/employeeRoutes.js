import express from 'express';
import { getEmployees, createEmployee } from '../controllers/employeeController.js';

const router = express.Router();

router.route('/').get(getEmployees).post(createEmployee);

export default router;
