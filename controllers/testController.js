const { sendResponse } = require('../utils/responseHelper');

// Mock data for testing
const MENU_ITEMS = [
    { id: 1, name: 'Breakfast', startTime: '08:00', endTime: '10:30' },
    { id: 2, name: 'Lunch', startTime: '12:00', endTime: '14:30' },
    { id: 3, name: 'Tea & Snacks', startTime: '16:00', endTime: '17:30' },
    { id: 4, name: 'Dinner', startTime: '19:30', endTime: '22:30' }
];

const PRE_BOOKINGS = {
    // employee ID -> Array of booked menu item IDs
    "EMP001": [1, 2],       // Booked Breakfast & Lunch
    "EMP002": [2, 3, 4],    // Booked Lunch, Snacks & Dinner
    "EMP003": [1, 4],       // Booked Breakfast & Dinner
    "EMP004": []            // No bookings
};

const EMPLOYEES = {
    "EMP001": { id: "EMP001", name: "Alice Johnson", empType: "permanent", couponType: "fixed" },
    "EMP002": { id: "EMP002", name: "Bob Smith", empType: "guest", couponType: "guest" },
    "EMP003": { id: "EMP003", name: "Charlie Brown", empType: "permanent", couponType: "fixed" },
    "EMP004": { id: "EMP004", name: "Diana Prince", empType: "guest", couponType: "guest" }
};

// Helper function to convert time string (HH:MM or HH:MM:SS) to minutes since midnight
const timeToMinutes = (timeStr) => {
    if (!timeStr) return 0;
    const parts = timeStr.split(':');
    const hours = parseInt(parts[0], 10) || 0;
    const minutes = parseInt(parts[1], 10) || 0;
    return hours * 60 + minutes;
};

/**
 * General testing endpoint for checking pre-booked menu items
 * POST /api/test/menu-booking
 */
const checkMenuBooking = async (req, res, next) => {
    try {
        // Token check for testing client-side token capability
        const authHeader = req.headers.authorization;
        const expectedToken = 'test-token-12345';
        
        let token = '';
        if (authHeader) {
            if (authHeader.startsWith('Bearer ')) {
                token = authHeader.substring(7);
            } else {
                token = authHeader;
            }
        }

        if (token !== expectedToken) {
            return res.status(401).json({
                success: false,
                message: 'Unauthorized: Invalid or missing test token (expected "test-token-12345")'
            });
        }

        const { empId, time } = req.body;
        const isAllMenuNeeded = false; // Hardcoded configuration for testing

        if (!empId) {
            return res.status(400).json({
                success: false,
                message: 'empId is required'
            });
        }

        // Fetch employee details
        const employee = EMPLOYEES[empId] || {
            id: empId,
            name: "",
            empType: "",
            couponType: ""
        };

        // If isAllMenuNeeded is true, return all pre-booked menu items for this employee
        if (isAllMenuNeeded === true) {
            const bookedIds = PRE_BOOKINGS[empId] || [];
            
            if (bookedIds.length === 0) {
                return res.status(200).json({
                    success: true,
                    booked: false,
                    message: 'No bookings found for today',
                    employee,
                    bookings: []
                });
            }

            const bookings = MENU_ITEMS.filter(item => bookedIds.includes(item.id));
            return res.status(200).json({
                success: true,
                booked: true,
                message: "Today's pre-booked menu items",
                employee,
                bookings
            });
        }

        // If isAllMenuNeeded is false, check for the menu item corresponding to the specified (or current) time
        let timeToCheck = time;
        if (!timeToCheck) {
            const now = new Date();
            const hours = String(now.getHours()).padStart(2, '0');
            const minutes = String(now.getMinutes()).padStart(2, '0');
            timeToCheck = `${hours}:${minutes}`;
        } else {
            let dateObj;
            if (typeof timeToCheck === 'number') {
                // Unix timestamp (seconds vs milliseconds)
                dateObj = new Date(timeToCheck < 9999999999 ? timeToCheck * 1000 : timeToCheck);
            } else if (typeof timeToCheck === 'string') {
                if (/^\d+$/.test(timeToCheck)) {
                    // Numeric string timestamp
                    const num = parseInt(timeToCheck, 10);
                    dateObj = new Date(num < 9999999999 ? num * 1000 : num);
                } else if (timeToCheck.includes('-') || timeToCheck.includes('/') || timeToCheck.includes('T') || timeToCheck.includes(' ')) {
                    // Try parsing as ISO / Date string
                    dateObj = new Date(timeToCheck);
                }
            }

            if (dateObj && !isNaN(dateObj.getTime())) {
                const hours = String(dateObj.getHours()).padStart(2, '0');
                const minutes = String(dateObj.getMinutes()).padStart(2, '0');
                timeToCheck = `${hours}:${minutes}`;
            }
        }

        const checkMinutes = timeToMinutes(timeToCheck);

        // Find the active menu item for this time
        const activeMenuItem = MENU_ITEMS.find(item => {
            const start = timeToMinutes(item.startTime);
            const end = timeToMinutes(item.endTime);
            return checkMinutes >= start && checkMinutes <= end;
        });

        if (!activeMenuItem) {
            return res.status(200).json({
                success: true,
                booked: false,
                message: `No active menu slot for the specified time (${timeToCheck})`,
                employee,
                bookings: []
            });
        }

        // Check if the employee has pre-booked this active menu item
        const bookedIds = PRE_BOOKINGS[empId] || [];
        const hasBooking = bookedIds.includes(activeMenuItem.id);

        if (hasBooking) {
            return res.status(200).json({
                success: true,
                booked: true,
                message: 'Pre-booked menu item found for the current time slot',
                employee,
                bookings: [activeMenuItem]
            });
        } else {
            return res.status(200).json({
                success: true,
                booked: false,
                message: 'No booking found for this menu slot',
                employee,
                bookings: []
            });
        }

    } catch (error) {
        next(error);
    }
};

module.exports = {
    checkMenuBooking
};
