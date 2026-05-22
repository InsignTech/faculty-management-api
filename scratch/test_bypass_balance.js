const LeaveRequestModel = require('../models/leaveRequestModel');
const pool = require('../config/db');

async function runTest() {
  console.log("=== Testing Super Admin Leave Bypass Balance check ===");
  
  // 1. Let's find an employee in employee_leaves
  const [empRows] = await pool.execute('SELECT DISTINCT emp_id FROM employee_leaves LIMIT 1');
  if (empRows.length === 0) {
    console.error("No employees found in employee_leaves to test against.");
    process.exit(1);
  }
  const testEmpId = empRows[0].emp_id;
  console.log(`Using Employee ID: ${testEmpId} for testing.`);

  // 2. Fetch their balances for testing
  const balances = await LeaveRequestModel.getLeaveBalance(testEmpId);
  console.log("Current Balances:", balances);

  if (balances.length === 0) {
    console.error("No active balance/policy found for the employee. Cannot run assertion tests.");
    process.exit(1);
  }

  const targetLeave = balances[0];
  const leaveType = targetLeave.leaveType;
  const currentAvailable = targetLeave.available;
  console.log(`Targeting leave type: ${leaveType} (Available: ${currentAvailable} days)`);

  const requestedDays = currentAvailable + 10;
  console.log(`Testing with ${requestedDays} requested days (which is > ${currentAvailable})...`);

  // Run Test 1: with check_balance = true (should fail with Insufficient balance)
  try {
    console.log("\n--- TEST 1: check_balance = true ---");
    await LeaveRequestModel.superAdminCreateLeave({
      employee_id: testEmpId,
      leave_type: leaveType,
      start_date: '2026-06-01',
      end_date: '2026-06-15', // dummy dates
      leave_half_type: 'FullDay',
      reason: 'Bypass test balance checked',
      total_days: requestedDays,
      check_balance: true
    }, 1);
    console.error("FAIL: Expected test 1 to fail with Insufficient balance, but it succeeded!");
  } catch (err) {
    console.log("SUCCESS: Test 1 failed as expected with message:", err.message);
    if (err.message.includes("Insufficient balance")) {
      console.log("PASS: Error message correctly mentions 'Insufficient balance'");
    } else {
      console.warn("WARN: Error message does not contain 'Insufficient balance'");
    }
  }

  // Run Test 2: with check_balance = false (should bypass check; we run in a transaction that we roll back)
  const conn = await pool.getConnection();
  try {
    console.log("\n--- TEST 2: check_balance = false ---");
    await conn.beginTransaction();

    // Since superAdminCreateLeave handles its own transaction, let's run it.
    // To avoid actually committing, we will let it run, but since it has its own transaction and commits,
    // we can delete the created record immediately after, OR we can run with check_balance = false and inspect success.
    // Wait! Let's see if we can run it.
    const res = await LeaveRequestModel.superAdminCreateLeave({
      employee_id: testEmpId,
      leave_type: leaveType,
      start_date: '2026-06-01',
      end_date: '2026-06-02',
      leave_half_type: 'FullDay',
      reason: 'Bypass test balance ignored',
      total_days: requestedDays,
      check_balance: false
    }, 1);

    console.log("SUCCESS: Test 2 succeeded as expected. Created leave request ID:", res.leave_request_id);
    
    // Clean up immediately
    await pool.execute('DELETE FROM leave_requests WHERE leave_request_id = ?', [res.leave_request_id]);
    console.log("Cleaned up created leave request from database.");
    console.log("PASS: Test 2 passed.");
  } catch (err) {
    console.error("FAIL: Expected test 2 to succeed, but it failed with error:", err.message);
  } finally {
    conn.release();
  }

  process.exit(0);
}

runTest();
