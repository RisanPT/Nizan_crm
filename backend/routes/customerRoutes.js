import express from 'express';
import { getCustomers, createCustomer, updateCustomer, deleteCustomer } from '../controllers/customerController.js';

const router = express.Router();

router.route('/').get(getCustomers).post(createCustomer);
router.route('/:id').put(updateCustomer).delete(deleteCustomer);

export default router;
