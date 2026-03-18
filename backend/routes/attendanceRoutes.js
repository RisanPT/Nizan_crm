import express from 'express';
import { getAttendances, markAttendance } from '../controllers/attendanceController.js';

const router = express.Router();

router.route('/').get(getAttendances).post(markAttendance);

export default router;
