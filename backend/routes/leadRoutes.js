import express from 'express';
import { getLeads, createLead } from '../controllers/leadController.js';

const router = express.Router();

router.route('/').get(getLeads).post(createLead);

export default router;
