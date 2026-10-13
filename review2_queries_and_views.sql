-- ============================================================================
-- DBMS PROJECT 41: CAMPUS FACILITY MAINTENANCE REQUEST MANAGEMENT SYSTEM
-- REVIEW 2: SAMPLE DATA POPULATION & 7 ANALYTICAL QUERIES / VIEWS
-- Run AFTER review2_schema_ddl.sql   |   Target: MySQL 8.0.16+
-- ============================================================================

USE CampusMaintenanceReview2;

-- ============================================================================
-- 1. MASTER / REFERENCE DATA
-- ============================================================================

INSERT INTO Building (BuildingID, BuildingCode, BuildingName, Floors) VALUES
(1, 'MAB', 'Main Academic Block', 4),
(2, 'SRB', 'Science & Research Block', 3),
(3, 'LIB', 'Central Library', 3),
(4, 'BHA', 'Boys Hostel A', 5),
(5, 'AAB', 'Auditorium & Admin Block', 2);

INSERT INTO Room (RoomID, BuildingID, RoomNo, FloorNo, RoomType) VALUES
(1, 1, '101', 1, 'Classroom'),
(2, 1, '204', 2, 'Classroom'),
(3, 1, '305', 3, 'Seminar Hall'),
(4, 2, 'LAB-1', 1, 'Laboratory'),
(5, 2, 'LAB-2', 1, 'Laboratory'),
(6, 2, '210', 2, 'Faculty Cabin'),
(7, 3, 'RR-1', 1, 'Reading Room'),
(8, 3, 'G-WASH', 0, 'Washroom'),
(9, 4, '112', 1, 'Hostel Room'),
(10, 4, 'MESS', 0, 'Mess Hall'),
(11, 5, 'MAIN-HALL', 1, 'Auditorium'),
(12, 5, 'OFFICE', 0, 'Admin Office');

INSERT INTO Asset (AssetID, RoomID, AssetTag, AssetName, InstalledOn) VALUES
(1, 1, 'AST-0001', 'Ceiling Fan', '2021-06-10'),
(2, 1, 'AST-0002', 'Ceiling Projector', '2022-01-15'),
(3, 2, 'AST-0003', 'Split AC 1.5T', '2020-04-20'),
(4, 2, 'AST-0004', 'Smart Board', '2023-07-01'),
(5, 4, 'AST-0005', 'Fume Hood', '2019-11-05'),
(6, 4, 'AST-0006', 'Water Purifier', '2022-09-12'),
(7, 7, 'AST-0007', 'LED Light Panel Set', '2021-02-18'),
(8, 8, 'AST-0008', 'Tap Set', '2018-08-30'),
(9, 11, 'AST-0009', 'Stage Lighting Rig', '2020-12-01'),
(10, 11, 'AST-0010', 'Split AC 2T', '2019-05-25'),
(11, 9, 'AST-0011', 'Wooden Cot', '2017-06-01'),
(12, 3, 'AST-0012', 'Podium', '2021-03-03');

INSERT INTO Campus_User (UserID, FullName, Email, Phone, Role) VALUES
(1, 'Dr. Meera Iyer', 'meera.iyer@campus.edu', '9848010001', 'Faculty'),
(2, 'Prof. Anil Kulkarni', 'anil.k@campus.edu', '9848010002', 'Faculty'),
(3, 'Rahul Verma', 'rahul.v@campus.edu', '9848010003', 'Student'),
(4, 'Sneha Reddy', 'sneha.r@campus.edu', '9848010004', 'Student'),
(5, 'Kiran Patel', 'kiran.p@campus.edu', '9848010005', 'Staff'),
(6, 'Farhan Ali', 'farhan.a@campus.edu', '9848010006', 'Student'),
(7, 'Lakshmi Narayanan', 'lakshmi.n@campus.edu', '9848010007', 'Staff'),
(8, 'Suresh Menon', 'suresh.m@campus.edu', '9848010008', 'Admin');

INSERT INTO Category (CategoryID, CategoryName) VALUES
(1, 'Classroom & AV'),
(2, 'Electrical'),
(3, 'Plumbing'),
(4, 'Furniture'),
(5, 'HVAC');

INSERT INTO Priority (PriorityID, PriorityName, TargetHours) VALUES
(1, 'Critical', 4),
(2, 'High', 24),
(3, 'Medium', 72),
(4, 'Low', 168);

INSERT INTO Technician (TechID, FullName, Phone, CategoryID, MaxActiveJobs, IsActive) VALUES
(1, 'Ramesh Babu', '9000100001', 2, 3, 1),
(2, 'Venkat Rao', '9000100002', 2, 3, 1),
(3, 'Mohd. Irfan', '9000100003', 3, 2, 1),
(4, 'Satish Kumar', '9000100004', 4, 4, 1),
(5, 'Anitha Devi', '9000100005', 1, 3, 1),
(6, 'Prakash Goud', '9000100006', 5, 2, 1),
(7, 'Joseph D''Souza', '9000100007', 3, 3, 0);

INSERT INTO Material (MaterialID, MaterialName, Unit, UnitCost, StockQty, ReorderLevel) VALUES
(1, 'LED Tube Light 18W', 'pcs', 180.00, 40, 15),
(2, 'Fan Capacitor', 'pcs', 85.00, 30, 10),
(3, 'MCB 16A', 'pcs', 240.00, 20, 8),
(4, 'Copper Wire 2.5mm', 'metre', 38.00, 200, 50),
(5, 'PVC Pipe 1 inch (3m)', 'pcs', 210.00, 25, 10),
(6, 'Tap Cartridge', 'pcs', 150.00, 15, 6),
(7, 'Plywood Sheet 8x4', 'sheet', 1650.00, 10, 4),
(8, 'Door Hinge Set', 'set', 120.00, 20, 6),
(9, 'AC Refrigerant R32', 'kg', 1100.00, 8, 4),
(10, 'Projector Lamp', 'pcs', 3800.00, 3, 2),
(11, 'PTFE Thread Seal Tape', 'roll', 25.00, 60, 20),
(12, 'Nut-Bolt Set M8', 'set', 95.00, 40, 15);

-- ============================================================================
-- 2. REQUEST LIFECYCLE DATA (loaded chronologically THROUGH the triggers)
-- @event_time back-dates trigger-generated Status_History rows; @app_user_id records
-- who made the change. The application leaves @event_time NULL, so NOW() is used.
-- ============================================================================

SET @event_time = '2026-08-03 09:15:00'; SET @app_user_id = 1;
INSERT INTO Maintenance_Request (RequestID, RequestNo, RequesterID, RoomID, AssetID, CategoryID, PriorityID, Description, CreatedAt) VALUES (1, 'REQ-2026-0001', 1, 1, 2, 1, 2, 'Ceiling projector not powering on during lectures', '2026-08-03 09:15:00');
SET @event_time = '2026-08-03 11:00:00'; SET @app_user_id = 8;
INSERT INTO Assignment (AssignmentID, RequestID, TechID, AssignedAt, Status) VALUES (1, 1, 5, '2026-08-03 11:00:00', 'Active');
SET @event_time = '2026-08-03 14:00:00'; SET @app_user_id = 8;
UPDATE Maintenance_Request SET Status = 'In Progress' WHERE RequestID = 1;
SET @event_time = '2026-08-03 14:30:00'; SET @app_user_id = 8;
INSERT INTO Work_Log (LogID, AssignmentID, LogTime, WorkNotes, HoursSpent) VALUES (1, 1, '2026-08-03 14:30:00', 'Diagnosed failed lamp', 1.5);
SET @event_time = '2026-08-04 10:00:00'; SET @app_user_id = 8;
INSERT INTO Work_Log (LogID, AssignmentID, LogTime, WorkNotes, HoursSpent) VALUES (2, 1, '2026-08-04 10:00:00', 'Replaced lamp and recalibrated', 1.0);
INSERT INTO Material_Usage (UsageID, LogID, MaterialID, Quantity, UnitCost) VALUES (1, 2, 10, 1, 3800.00);
SET @event_time = '2026-08-04 11:30:00'; SET @app_user_id = 8;
UPDATE Assignment SET Status = 'Completed', CompletedAt = '2026-08-04 11:30:00' WHERE AssignmentID = 1;
SET @event_time = '2026-08-04 11:30:00'; SET @app_user_id = 8;
INSERT INTO Request_Cost (CostID, RequestID, CostType, Amount, Remarks) VALUES (1, 1, 'Labour', 600.00, 'Technician labour');
SET @event_time = '2026-08-04 11:30:00'; SET @app_user_id = 8;
UPDATE Maintenance_Request SET Status = 'Resolved' WHERE RequestID = 1;
SET @event_time = '2026-08-04 16:00:00'; SET @app_user_id = 8;
UPDATE Maintenance_Request SET Status = 'Closed', ClosedAt = '2026-08-04 16:00:00', ClosureRemarks = 'Lamp replaced, projector tested OK' WHERE RequestID = 1;
SET @event_time = '2026-08-04 18:00:00'; SET @app_user_id = 1;
INSERT INTO Feedback (FeedbackID, RequestID, Rating, Comments, SubmittedAt) VALUES (1, 1, 5, 'Quick and clean work', '2026-08-04 18:00:00');
SET @event_time = '2026-08-10 10:05:00'; SET @app_user_id = 2;
INSERT INTO Maintenance_Request (RequestID, RequestNo, RequesterID, RoomID, AssetID, CategoryID, PriorityID, Description, CreatedAt) VALUES (2, 'REQ-2026-0002', 2, 4, 5, 2, 1, 'Fume hood exhaust fan sparking', '2026-08-10 10:05:00');
SET @event_time = '2026-08-10 10:35:00'; SET @app_user_id = 8;
INSERT INTO Assignment (AssignmentID, RequestID, TechID, AssignedAt, Status) VALUES (2, 2, 1, '2026-08-10 10:35:00', 'Active');
SET @event_time = '2026-08-10 10:50:00'; SET @app_user_id = 8;
UPDATE Maintenance_Request SET Status = 'In Progress' WHERE RequestID = 2;
SET @event_time = '2026-08-10 11:00:00'; SET @app_user_id = 8;
INSERT INTO Work_Log (LogID, AssignmentID, LogTime, WorkNotes, HoursSpent) VALUES (3, 2, '2026-08-10 11:00:00', 'Isolated supply, replaced burnt capacitor', 2.0);
INSERT INTO Material_Usage (UsageID, LogID, MaterialID, Quantity, UnitCost) VALUES (2, 3, 2, 2, 85.00);
INSERT INTO Material_Usage (UsageID, LogID, MaterialID, Quantity, UnitCost) VALUES (3, 3, 3, 1, 240.00);
SET @event_time = '2026-08-10 14:00:00'; SET @app_user_id = 8;
UPDATE Assignment SET Status = 'Completed', CompletedAt = '2026-08-10 14:00:00' WHERE AssignmentID = 2;
SET @event_time = '2026-08-10 14:00:00'; SET @app_user_id = 8;
INSERT INTO Request_Cost (CostID, RequestID, CostType, Amount, Remarks) VALUES (2, 2, 'Labour', 800.00, 'Emergency call-out');
SET @event_time = '2026-08-10 14:00:00'; SET @app_user_id = 8;
UPDATE Maintenance_Request SET Status = 'Resolved' WHERE RequestID = 2;
SET @event_time = '2026-08-11 09:30:00'; SET @app_user_id = 8;
UPDATE Maintenance_Request SET Status = 'Closed', ClosedAt = '2026-08-11 09:30:00', ClosureRemarks = 'Capacitor and MCB replaced, lab cleared for use' WHERE RequestID = 2;
SET @event_time = '2026-08-11 12:00:00'; SET @app_user_id = 2;
INSERT INTO Feedback (FeedbackID, RequestID, Rating, Comments, SubmittedAt) VALUES (2, 2, 4, 'Fast response', '2026-08-11 12:00:00');
SET @event_time = '2026-08-12 18:20:00'; SET @app_user_id = 3;
INSERT INTO Maintenance_Request (RequestID, RequestNo, RequesterID, RoomID, AssetID, CategoryID, PriorityID, Description, CreatedAt) VALUES (3, 'REQ-2026-0003', 3, 9, 11, 4, 4, 'Cot frame broken, loose joints', '2026-08-12 18:20:00');
SET @event_time = '2026-08-14 10:00:00'; SET @app_user_id = 8;
INSERT INTO Assignment (AssignmentID, RequestID, TechID, AssignedAt, Status) VALUES (3, 3, 4, '2026-08-14 10:00:00', 'Active');
SET @event_time = '2026-08-14 11:00:00'; SET @app_user_id = 8;
UPDATE Maintenance_Request SET Status = 'In Progress' WHERE RequestID = 3;
SET @event_time = '2026-08-14 11:30:00'; SET @app_user_id = 8;
INSERT INTO Work_Log (LogID, AssignmentID, LogTime, WorkNotes, HoursSpent) VALUES (4, 3, '2026-08-14 11:30:00', 'Welded joint, replaced bolts', 2.5);
INSERT INTO Material_Usage (UsageID, LogID, MaterialID, Quantity, UnitCost) VALUES (4, 4, 12, 2, 95.00);
SET @event_time = '2026-08-14 15:00:00'; SET @app_user_id = 8;
UPDATE Assignment SET Status = 'Completed', CompletedAt = '2026-08-14 15:00:00' WHERE AssignmentID = 3;
SET @event_time = '2026-08-14 15:00:00'; SET @app_user_id = 8;
INSERT INTO Request_Cost (CostID, RequestID, CostType, Amount, Remarks) VALUES (3, 3, 'Labour', 400.00, 'Welding');
SET @event_time = '2026-08-14 15:00:00'; SET @app_user_id = 8;
UPDATE Maintenance_Request SET Status = 'Resolved' WHERE RequestID = 3;
SET @event_time = '2026-08-15 10:00:00'; SET @app_user_id = 8;
UPDATE Maintenance_Request SET Status = 'Closed', ClosedAt = '2026-08-15 10:00:00', ClosureRemarks = 'Frame repaired and tested' WHERE RequestID = 3;
SET @event_time = '2026-08-15 12:30:00'; SET @app_user_id = 3;
INSERT INTO Feedback (FeedbackID, RequestID, Rating, Comments, SubmittedAt) VALUES (3, 3, 3, 'Fixed but took two days', '2026-08-15 12:30:00');
SET @event_time = '2026-08-20 08:40:00'; SET @app_user_id = 4;
INSERT INTO Maintenance_Request (RequestID, RequestNo, RequesterID, RoomID, AssetID, CategoryID, PriorityID, Description, CreatedAt) VALUES (4, 'REQ-2026-0004', 4, 8, 8, 3, 2, 'Tap leaking continuously in ground-floor washroom', '2026-08-20 08:40:00');
SET @event_time = '2026-08-21 10:00:00'; SET @app_user_id = 8;
INSERT INTO Assignment (AssignmentID, RequestID, TechID, AssignedAt, Status) VALUES (4, 4, 3, '2026-08-21 10:00:00', 'Active');
SET @event_time = '2026-08-21 10:30:00'; SET @app_user_id = 8;
UPDATE Maintenance_Request SET Status = 'In Progress' WHERE RequestID = 4;
SET @event_time = '2026-08-21 10:45:00'; SET @app_user_id = 8;
INSERT INTO Work_Log (LogID, AssignmentID, LogTime, WorkNotes, HoursSpent) VALUES (5, 4, '2026-08-21 10:45:00', 'Replaced cartridge and seal tape', 1.0);
INSERT INTO Material_Usage (UsageID, LogID, MaterialID, Quantity, UnitCost) VALUES (5, 5, 6, 2, 150.00);
INSERT INTO Material_Usage (UsageID, LogID, MaterialID, Quantity, UnitCost) VALUES (6, 5, 11, 1, 25.00);
SET @event_time = '2026-08-21 12:00:00'; SET @app_user_id = 8;
UPDATE Assignment SET Status = 'Completed', CompletedAt = '2026-08-21 12:00:00' WHERE AssignmentID = 4;
SET @event_time = '2026-08-21 12:00:00'; SET @app_user_id = 8;
INSERT INTO Request_Cost (CostID, RequestID, CostType, Amount, Remarks) VALUES (4, 4, 'Labour', 300.00, 'Technician labour');
SET @event_time = '2026-08-21 12:00:00'; SET @app_user_id = 8;
UPDATE Maintenance_Request SET Status = 'Resolved' WHERE RequestID = 4;
SET @event_time = '2026-08-21 17:30:00'; SET @app_user_id = 8;
UPDATE Maintenance_Request SET Status = 'Closed', ClosedAt = '2026-08-21 17:30:00', ClosureRemarks = 'Leak fixed, no seepage after 2 hours' WHERE RequestID = 4;
SET @event_time = '2026-08-21 19:30:00'; SET @app_user_id = 4;
INSERT INTO Feedback (FeedbackID, RequestID, Rating, Comments, SubmittedAt) VALUES (4, 4, 5, 'Problem solved', '2026-08-21 19:30:00');
SET @event_time = '2026-08-28 11:00:00'; SET @app_user_id = 5;
INSERT INTO Maintenance_Request (RequestID, RequestNo, RequesterID, RoomID, AssetID, CategoryID, PriorityID, Description, CreatedAt) VALUES (5, 'REQ-2026-0005', 5, 11, 10, 5, 3, 'Auditorium AC not cooling', '2026-08-28 11:00:00');
SET @event_time = '2026-08-29 09:30:00'; SET @app_user_id = 8;
INSERT INTO Assignment (AssignmentID, RequestID, TechID, AssignedAt, Status) VALUES (5, 5, 6, '2026-08-29 09:30:00', 'Active');
SET @event_time = '2026-08-29 10:00:00'; SET @app_user_id = 8;
UPDATE Maintenance_Request SET Status = 'In Progress' WHERE RequestID = 5;
SET @event_time = '2026-08-29 10:30:00'; SET @app_user_id = 8;
INSERT INTO Work_Log (LogID, AssignmentID, LogTime, WorkNotes, HoursSpent) VALUES (6, 5, '2026-08-29 10:30:00', 'Gas leak found at flare joint', 2.0);
SET @event_time = '2026-08-30 11:00:00'; SET @app_user_id = 8;
INSERT INTO Work_Log (LogID, AssignmentID, LogTime, WorkNotes, HoursSpent) VALUES (7, 5, '2026-08-30 11:00:00', 'Brazed joint and recharged R32', 3.0);
INSERT INTO Material_Usage (UsageID, LogID, MaterialID, Quantity, UnitCost) VALUES (7, 7, 9, 2, 1100.00);
SET @event_time = '2026-08-30 15:00:00'; SET @app_user_id = 8;
UPDATE Assignment SET Status = 'Completed', CompletedAt = '2026-08-30 15:00:00' WHERE AssignmentID = 5;
SET @event_time = '2026-08-30 15:00:00'; SET @app_user_id = 8;
INSERT INTO Request_Cost (CostID, RequestID, CostType, Amount, Remarks) VALUES (5, 5, 'Labour', 1500.00, 'HVAC labour');
SET @event_time = '2026-08-30 15:00:00'; SET @app_user_id = 8;
INSERT INTO Request_Cost (CostID, RequestID, CostType, Amount, Remarks) VALUES (6, 5, 'Vendor', 1200.00, 'Brazing contractor');
SET @event_time = '2026-08-30 15:00:00'; SET @app_user_id = 8;
UPDATE Maintenance_Request SET Status = 'Resolved' WHERE RequestID = 5;
SET @event_time = '2026-09-01 10:00:00'; SET @app_user_id = 8;
UPDATE Maintenance_Request SET Status = 'Closed', ClosedAt = '2026-09-01 10:00:00', ClosureRemarks = 'Leak sealed, cooling restored to 22C' WHERE RequestID = 5;
SET @event_time = '2026-09-01 12:00:00'; SET @app_user_id = 5;
INSERT INTO Feedback (FeedbackID, RequestID, Rating, Comments, SubmittedAt) VALUES (5, 5, 4, 'Cooling is good now', '2026-09-01 12:00:00');
SET @event_time = '2026-09-02 19:30:00'; SET @app_user_id = 6;
INSERT INTO Maintenance_Request (RequestID, RequestNo, RequesterID, RoomID, AssetID, CategoryID, PriorityID, Description, CreatedAt) VALUES (6, 'REQ-2026-0006', 6, 10, NULL, 2, 2, 'Mess hall tube lights flickering', '2026-09-02 19:30:00');
SET @event_time = '2026-09-03 09:00:00'; SET @app_user_id = 8;
INSERT INTO Assignment (AssignmentID, RequestID, TechID, AssignedAt, Status) VALUES (6, 6, 2, '2026-09-03 09:00:00', 'Active');
SET @event_time = '2026-09-03 10:00:00'; SET @app_user_id = 8;
UPDATE Maintenance_Request SET Status = 'In Progress' WHERE RequestID = 6;
SET @event_time = '2026-09-03 10:30:00'; SET @app_user_id = 8;
INSERT INTO Work_Log (LogID, AssignmentID, LogTime, WorkNotes, HoursSpent) VALUES (8, 6, '2026-09-03 10:30:00', 'Replaced six tube lights', 1.5);
INSERT INTO Material_Usage (UsageID, LogID, MaterialID, Quantity, UnitCost) VALUES (8, 8, 1, 6, 180.00);
SET @event_time = '2026-09-03 12:30:00'; SET @app_user_id = 8;
UPDATE Assignment SET Status = 'Completed', CompletedAt = '2026-09-03 12:30:00' WHERE AssignmentID = 6;
SET @event_time = '2026-09-03 12:30:00'; SET @app_user_id = 8;
INSERT INTO Request_Cost (CostID, RequestID, CostType, Amount, Remarks) VALUES (7, 6, 'Labour', 350.00, 'Technician labour');
SET @event_time = '2026-09-03 12:30:00'; SET @app_user_id = 8;
UPDATE Maintenance_Request SET Status = 'Resolved' WHERE RequestID = 6;
SET @event_time = '2026-09-04 09:00:00'; SET @app_user_id = 8;
UPDATE Maintenance_Request SET Status = 'Closed', ClosedAt = '2026-09-04 09:00:00', ClosureRemarks = 'All tube lights replaced' WHERE RequestID = 6;
SET @event_time = '2026-09-04 11:00:00'; SET @app_user_id = 6;
INSERT INTO Feedback (FeedbackID, RequestID, Rating, Comments, SubmittedAt) VALUES (6, 6, 5, 'Bright again', '2026-09-04 11:00:00');
SET @event_time = '2026-09-05 10:10:00'; SET @app_user_id = 1;
INSERT INTO Maintenance_Request (RequestID, RequestNo, RequesterID, RoomID, AssetID, CategoryID, PriorityID, Description, CreatedAt) VALUES (7, 'REQ-2026-0007', 1, 2, 3, 5, 3, 'Split AC making loud noise', '2026-09-05 10:10:00');
SET @event_time = '2026-09-05 15:00:00'; SET @app_user_id = 8;
INSERT INTO Assignment (AssignmentID, RequestID, TechID, AssignedAt, Status) VALUES (7, 7, 6, '2026-09-05 15:00:00', 'Active');
SET @event_time = '2026-09-06 10:00:00'; SET @app_user_id = 8;
UPDATE Maintenance_Request SET Status = 'In Progress' WHERE RequestID = 7;
SET @event_time = '2026-09-06 10:30:00'; SET @app_user_id = 8;
INSERT INTO Work_Log (LogID, AssignmentID, LogTime, WorkNotes, HoursSpent) VALUES (9, 7, '2026-09-06 10:30:00', 'Cleaned condenser, tightened fan motor mounts', 2.5);
SET @event_time = '2026-09-06 14:00:00'; SET @app_user_id = 8;
UPDATE Assignment SET Status = 'Completed', CompletedAt = '2026-09-06 14:00:00' WHERE AssignmentID = 7;
SET @event_time = '2026-09-06 14:00:00'; SET @app_user_id = 8;
INSERT INTO Request_Cost (CostID, RequestID, CostType, Amount, Remarks) VALUES (8, 7, 'Labour', 500.00, 'HVAC labour');
SET @event_time = '2026-09-06 14:00:00'; SET @app_user_id = 8;
UPDATE Maintenance_Request SET Status = 'Resolved' WHERE RequestID = 7;
SET @event_time = '2026-09-07 09:30:00'; SET @app_user_id = 8;
UPDATE Maintenance_Request SET Status = 'Closed', ClosedAt = '2026-09-07 09:30:00', ClosureRemarks = 'Noise eliminated after servicing' WHERE RequestID = 7;
SET @event_time = '2026-09-07 11:00:00'; SET @app_user_id = 1;
INSERT INTO Feedback (FeedbackID, RequestID, Rating, Comments, SubmittedAt) VALUES (7, 7, 4, 'Quiet now', '2026-09-07 11:00:00');
SET @event_time = '2026-09-10 09:00:00'; SET @app_user_id = 7;
INSERT INTO Maintenance_Request (RequestID, RequestNo, RequesterID, RoomID, AssetID, CategoryID, PriorityID, Description, CreatedAt) VALUES (8, 'REQ-2026-0008', 7, 7, 7, 2, 3, 'Light panels dim in reading room', '2026-09-10 09:00:00');
SET @event_time = '2026-09-14 09:00:00'; SET @app_user_id = 8;
INSERT INTO Assignment (AssignmentID, RequestID, TechID, AssignedAt, Status) VALUES (8, 8, 1, '2026-09-14 09:00:00', 'Active');
SET @event_time = '2026-09-14 10:00:00'; SET @app_user_id = 8;
UPDATE Maintenance_Request SET Status = 'In Progress' WHERE RequestID = 8;
SET @event_time = '2026-09-14 10:30:00'; SET @app_user_id = 8;
INSERT INTO Work_Log (LogID, AssignmentID, LogTime, WorkNotes, HoursSpent) VALUES (10, 8, '2026-09-14 10:30:00', 'Replaced four panel drivers', 3.0);
INSERT INTO Material_Usage (UsageID, LogID, MaterialID, Quantity, UnitCost) VALUES (9, 10, 1, 4, 180.00);
SET @event_time = '2026-09-14 14:00:00'; SET @app_user_id = 8;
UPDATE Assignment SET Status = 'Completed', CompletedAt = '2026-09-14 14:00:00' WHERE AssignmentID = 8;
SET @event_time = '2026-09-14 14:00:00'; SET @app_user_id = 8;
INSERT INTO Request_Cost (CostID, RequestID, CostType, Amount, Remarks) VALUES (9, 8, 'Labour', 600.00, 'Technician labour');
SET @event_time = '2026-09-14 14:00:00'; SET @app_user_id = 8;
UPDATE Maintenance_Request SET Status = 'Resolved' WHERE RequestID = 8;
SET @event_time = '2026-09-15 09:00:00'; SET @app_user_id = 8;
UPDATE Maintenance_Request SET Status = 'Closed', ClosedAt = '2026-09-15 09:00:00', ClosureRemarks = 'Drivers replaced, brightness restored' WHERE RequestID = 8;
SET @event_time = '2026-09-15 12:00:00'; SET @app_user_id = 2;
INSERT INTO Maintenance_Request (RequestID, RequestNo, RequesterID, RoomID, AssetID, CategoryID, PriorityID, Description, CreatedAt) VALUES (9, 'REQ-2026-0009', 2, 3, 12, 4, 4, 'Podium drawer lock jammed', '2026-09-15 12:00:00');
SET @event_time = '2026-09-15 15:00:00'; SET @app_user_id = 7;
INSERT INTO Feedback (FeedbackID, RequestID, Rating, Comments, SubmittedAt) VALUES (8, 8, 2, 'Dimmed again after a week', '2026-09-15 15:00:00');
SET @event_time = '2026-09-17 11:00:00'; SET @app_user_id = 8;
INSERT INTO Assignment (AssignmentID, RequestID, TechID, AssignedAt, Status) VALUES (9, 9, 4, '2026-09-17 11:00:00', 'Active');
SET @event_time = '2026-09-17 11:30:00'; SET @app_user_id = 8;
UPDATE Maintenance_Request SET Status = 'In Progress' WHERE RequestID = 9;
SET @event_time = '2026-09-17 12:00:00'; SET @app_user_id = 8;
INSERT INTO Work_Log (LogID, AssignmentID, LogTime, WorkNotes, HoursSpent) VALUES (11, 9, '2026-09-17 12:00:00', 'Replaced lock mechanism', 1.0);
INSERT INTO Material_Usage (UsageID, LogID, MaterialID, Quantity, UnitCost) VALUES (10, 11, 8, 1, 120.00);
SET @event_time = '2026-09-17 13:30:00'; SET @app_user_id = 8;
UPDATE Assignment SET Status = 'Completed', CompletedAt = '2026-09-17 13:30:00' WHERE AssignmentID = 9;
SET @event_time = '2026-09-17 13:30:00'; SET @app_user_id = 8;
INSERT INTO Request_Cost (CostID, RequestID, CostType, Amount, Remarks) VALUES (10, 9, 'Labour', 250.00, 'Carpentry');
SET @event_time = '2026-09-17 13:30:00'; SET @app_user_id = 8;
UPDATE Maintenance_Request SET Status = 'Resolved' WHERE RequestID = 9;
SET @event_time = '2026-09-18 10:00:00'; SET @app_user_id = 8;
UPDATE Maintenance_Request SET Status = 'Closed', ClosedAt = '2026-09-18 10:00:00', ClosureRemarks = 'Lock replaced' WHERE RequestID = 9;
SET @event_time = '2026-09-18 12:00:00'; SET @app_user_id = 2;
INSERT INTO Feedback (FeedbackID, RequestID, Rating, Comments, SubmittedAt) VALUES (9, 9, 4, 'Works smoothly', '2026-09-18 12:00:00');
SET @event_time = '2026-09-20 09:20:00'; SET @app_user_id = 3;
INSERT INTO Maintenance_Request (RequestID, RequestNo, RequesterID, RoomID, AssetID, CategoryID, PriorityID, Description, CreatedAt) VALUES (10, 'REQ-2026-0010', 3, 5, NULL, 2, 2, 'Power sockets dead on bench 3', '2026-09-20 09:20:00');
SET @event_time = '2026-09-20 10:00:00'; SET @app_user_id = 8;
INSERT INTO Assignment (AssignmentID, RequestID, TechID, AssignedAt, Status) VALUES (10, 10, 2, '2026-09-20 10:00:00', 'Active');
SET @event_time = '2026-09-20 13:00:00'; SET @app_user_id = 8;
UPDATE Assignment SET Status = 'Reassigned', CompletedAt = '2026-09-20 13:00:00' WHERE AssignmentID = 10;
SET @event_time = '2026-09-20 13:30:00'; SET @app_user_id = 8;
INSERT INTO Assignment (AssignmentID, RequestID, TechID, AssignedAt, Status) VALUES (11, 10, 1, '2026-09-20 13:30:00', 'Active');
SET @event_time = '2026-09-20 14:00:00'; SET @app_user_id = 8;
UPDATE Maintenance_Request SET Status = 'In Progress' WHERE RequestID = 10;
SET @event_time = '2026-09-20 14:15:00'; SET @app_user_id = 8;
INSERT INTO Work_Log (LogID, AssignmentID, LogTime, WorkNotes, HoursSpent) VALUES (12, 11, '2026-09-20 14:15:00', 'Traced broken neutral, rewired socket line', 2.5);
INSERT INTO Material_Usage (UsageID, LogID, MaterialID, Quantity, UnitCost) VALUES (11, 12, 4, 12, 38.00);
INSERT INTO Material_Usage (UsageID, LogID, MaterialID, Quantity, UnitCost) VALUES (12, 12, 3, 1, 240.00);
SET @event_time = '2026-09-20 17:00:00'; SET @app_user_id = 8;
UPDATE Assignment SET Status = 'Completed', CompletedAt = '2026-09-20 17:00:00' WHERE AssignmentID = 11;
SET @event_time = '2026-09-20 17:00:00'; SET @app_user_id = 8;
INSERT INTO Request_Cost (CostID, RequestID, CostType, Amount, Remarks) VALUES (11, 10, 'Labour', 700.00, 'Technician labour');
SET @event_time = '2026-09-20 17:00:00'; SET @app_user_id = 8;
UPDATE Maintenance_Request SET Status = 'Resolved' WHERE RequestID = 10;
SET @event_time = '2026-09-21 09:30:00'; SET @app_user_id = 8;
UPDATE Maintenance_Request SET Status = 'Closed', ClosedAt = '2026-09-21 09:30:00', ClosureRemarks = 'Bench 3 sockets restored' WHERE RequestID = 10;
SET @event_time = '2026-09-21 11:00:00'; SET @app_user_id = 3;
INSERT INTO Feedback (FeedbackID, RequestID, Rating, Comments, SubmittedAt) VALUES (10, 10, 5, 'Excellent', '2026-09-21 11:00:00');
SET @event_time = '2026-10-02 11:00:00'; SET @app_user_id = 5;
INSERT INTO Maintenance_Request (RequestID, RequestNo, RequesterID, RoomID, AssetID, CategoryID, PriorityID, Description, CreatedAt) VALUES (11, 'REQ-2026-0011', 5, 11, 9, 2, 2, 'Stage lighting dimmer channel failed', '2026-10-02 11:00:00');
SET @event_time = '2026-10-02 15:00:00'; SET @app_user_id = 8;
INSERT INTO Assignment (AssignmentID, RequestID, TechID, AssignedAt, Status) VALUES (12, 11, 2, '2026-10-02 15:00:00', 'Active');
SET @event_time = '2026-10-03 09:00:00'; SET @app_user_id = 8;
UPDATE Maintenance_Request SET Status = 'In Progress' WHERE RequestID = 11;
SET @event_time = '2026-10-03 09:30:00'; SET @app_user_id = 8;
INSERT INTO Work_Log (LogID, AssignmentID, LogTime, WorkNotes, HoursSpent) VALUES (13, 12, '2026-10-03 09:30:00', 'Dimmer module faulty; replacement part ordered', 2.0);
SET @event_time = '2026-10-03 12:00:00'; SET @app_user_id = 8;
UPDATE Maintenance_Request SET Status = 'On Hold' WHERE RequestID = 11;
SET @event_time = '2026-10-03 14:00:00'; SET @app_user_id = 4;
INSERT INTO Maintenance_Request (RequestID, RequestNo, RequesterID, RoomID, AssetID, CategoryID, PriorityID, Description, CreatedAt) VALUES (12, 'REQ-2026-0012', 4, 1, 1, 2, 4, 'Ceiling fan wobbling and noisy', '2026-10-03 14:00:00');
SET @event_time = '2026-10-05 10:00:00'; SET @app_user_id = 5;
INSERT INTO Maintenance_Request (RequestID, RequestNo, RequesterID, RoomID, AssetID, CategoryID, PriorityID, Description, CreatedAt) VALUES (13, 'REQ-2026-0013', 5, 12, NULL, 3, 3, 'Drinking water cooler leaking', '2026-10-05 10:00:00');
SET @event_time = '2026-10-06 09:00:00'; SET @app_user_id = 7;
INSERT INTO Maintenance_Request (RequestID, RequestNo, RequesterID, RoomID, AssetID, CategoryID, PriorityID, Description, CreatedAt) VALUES (14, 'REQ-2026-0014', 7, 7, NULL, 1, 4, 'Projector issue (duplicate entry)', '2026-10-06 09:00:00');
SET @event_time = '2026-10-06 09:30:00'; SET @app_user_id = 8;
INSERT INTO Assignment (AssignmentID, RequestID, TechID, AssignedAt, Status) VALUES (13, 13, 3, '2026-10-06 09:30:00', 'Active');
SET @event_time = '2026-10-06 10:00:00'; SET @app_user_id = 8;
UPDATE Maintenance_Request SET Status = 'In Progress' WHERE RequestID = 13;
SET @event_time = '2026-10-06 10:00:00'; SET @app_user_id = 8;
UPDATE Maintenance_Request SET Status = 'Cancelled', ClosureRemarks = 'Duplicate of an existing request' WHERE RequestID = 14;
SET @event_time = '2026-10-06 10:30:00'; SET @app_user_id = 8;
INSERT INTO Work_Log (LogID, AssignmentID, LogTime, WorkNotes, HoursSpent) VALUES (14, 13, '2026-10-06 10:30:00', 'Replaced inlet pipe and sealed joint', 2.0);
INSERT INTO Material_Usage (UsageID, LogID, MaterialID, Quantity, UnitCost) VALUES (13, 14, 5, 1, 210.00);
INSERT INTO Material_Usage (UsageID, LogID, MaterialID, Quantity, UnitCost) VALUES (14, 14, 11, 1, 25.00);
SET @event_time = '2026-10-06 13:00:00'; SET @app_user_id = 8;
UPDATE Assignment SET Status = 'Completed', CompletedAt = '2026-10-06 13:00:00' WHERE AssignmentID = 13;
SET @event_time = '2026-10-06 13:00:00'; SET @app_user_id = 8;
INSERT INTO Request_Cost (CostID, RequestID, CostType, Amount, Remarks) VALUES (12, 13, 'Labour', 300.00, 'Technician labour');
SET @event_time = '2026-10-06 13:00:00'; SET @app_user_id = 8;
UPDATE Maintenance_Request SET Status = 'Resolved' WHERE RequestID = 13;
SET @event_time = '2026-10-07 10:00:00'; SET @app_user_id = 8;
INSERT INTO Assignment (AssignmentID, RequestID, TechID, AssignedAt, Status) VALUES (14, 12, 1, '2026-10-07 10:00:00', 'Active');
SET @event_time = '2026-10-08 09:30:00'; SET @app_user_id = 1;
INSERT INTO Maintenance_Request (RequestID, RequestNo, RequesterID, RoomID, AssetID, CategoryID, PriorityID, Description, CreatedAt) VALUES (15, 'REQ-2026-0015', 1, 2, 4, 1, 3, 'Smart board touch calibration drifting', '2026-10-08 09:30:00');
SET @event_time = '2026-10-08 10:00:00'; SET @app_user_id = 8;
UPDATE Maintenance_Request SET Status = 'In Progress' WHERE RequestID = 12;
SET @event_time = '2026-10-08 10:30:00'; SET @app_user_id = 8;
INSERT INTO Work_Log (LogID, AssignmentID, LogTime, WorkNotes, HoursSpent) VALUES (15, 14, '2026-10-08 10:30:00', 'Balanced blades, new capacitor fitted', 1.0);
INSERT INTO Material_Usage (UsageID, LogID, MaterialID, Quantity, UnitCost) VALUES (15, 15, 2, 1, 85.00);
SET @event_time = '2026-10-08 13:00:00'; SET @app_user_id = 4;
INSERT INTO Maintenance_Request (RequestID, RequestNo, RequesterID, RoomID, AssetID, CategoryID, PriorityID, Description, CreatedAt) VALUES (16, 'REQ-2026-0016', 4, 8, NULL, 3, 4, 'Hand-wash basin drain draining slowly', '2026-10-08 13:00:00');
SET @event_time = '2026-10-09 07:45:00'; SET @app_user_id = 6;
INSERT INTO Maintenance_Request (RequestID, RequestNo, RequesterID, RoomID, AssetID, CategoryID, PriorityID, Description, CreatedAt) VALUES (17, 'REQ-2026-0017', 6, 9, NULL, 3, 2, 'Bathroom flush tank overflow', '2026-10-09 07:45:00');
SET @event_time = '2026-10-09 10:00:00'; SET @app_user_id = 8;
INSERT INTO Assignment (AssignmentID, RequestID, TechID, AssignedAt, Status) VALUES (15, 15, 5, '2026-10-09 10:00:00', 'Active');
SET @event_time = '2026-10-09 11:00:00'; SET @app_user_id = 8;
INSERT INTO Assignment (AssignmentID, RequestID, TechID, AssignedAt, Status) VALUES (16, 17, 3, '2026-10-09 11:00:00', 'Active');
SET @event_time = '2026-10-09 12:00:00'; SET @app_user_id = 8;
UPDATE Maintenance_Request SET Status = 'In Progress' WHERE RequestID = 17;
SET @event_time = '2026-10-09 12:30:00'; SET @app_user_id = 8;
INSERT INTO Work_Log (LogID, AssignmentID, LogTime, WorkNotes, HoursSpent) VALUES (16, 16, '2026-10-09 12:30:00', 'Flush valve resealed; pipeline check pending', 1.5);
INSERT INTO Material_Usage (UsageID, LogID, MaterialID, Quantity, UnitCost) VALUES (16, 16, 11, 2, 25.00);
SET @event_time = '2026-10-09 15:30:00'; SET @app_user_id = 2;
INSERT INTO Maintenance_Request (RequestID, RequestNo, RequesterID, RoomID, AssetID, CategoryID, PriorityID, Description, CreatedAt) VALUES (18, 'REQ-2026-0018', 2, 4, 6, 3, 3, 'Water purifier showing no output', '2026-10-09 15:30:00');
SET @event_time = '2026-10-10 09:00:00'; SET @app_user_id = 8;
INSERT INTO Assignment (AssignmentID, RequestID, TechID, AssignedAt, Status) VALUES (17, 18, 3, '2026-10-10 09:00:00', 'Active');
SET @event_time = '2026-10-10 10:00:00'; SET @app_user_id = 7;
INSERT INTO Maintenance_Request (RequestID, RequestNo, RequesterID, RoomID, AssetID, CategoryID, PriorityID, Description, CreatedAt) VALUES (19, 'REQ-2026-0019', 7, 7, NULL, 4, 3, 'Reading tables wobbling (3 tables)', '2026-10-10 10:00:00');
SET @event_time = '2026-10-10 11:00:00'; SET @app_user_id = 8;
UPDATE Maintenance_Request SET Status = 'In Progress' WHERE RequestID = 15;
SET @event_time = '2026-10-10 11:30:00'; SET @app_user_id = 8;
INSERT INTO Work_Log (LogID, AssignmentID, LogTime, WorkNotes, HoursSpent) VALUES (17, 15, '2026-10-10 11:30:00', 'Firmware updated; testing touch layer', 1.0);
SET @event_time = '2026-10-11 09:30:00'; SET @app_user_id = 8;
INSERT INTO Assignment (AssignmentID, RequestID, TechID, AssignedAt, Status) VALUES (18, 19, 4, '2026-10-11 09:30:00', 'Active');
SET @event_time = '2026-10-11 16:20:00'; SET @app_user_id = 3;
INSERT INTO Maintenance_Request (RequestID, RequestNo, RequesterID, RoomID, AssetID, CategoryID, PriorityID, Description, CreatedAt) VALUES (20, 'REQ-2026-0020', 3, 2, NULL, 1, 3, 'Whiteboard surface peeling', '2026-10-11 16:20:00');
SET @event_time = '2026-10-11 17:00:00'; SET @app_user_id = 6;
INSERT INTO Maintenance_Request (RequestID, RequestNo, RequesterID, RoomID, AssetID, CategoryID, PriorityID, Description, CreatedAt) VALUES (21, 'REQ-2026-0021', 6, 10, NULL, 2, 1, 'Kitchen exhaust fan stopped, smoke accumulating', '2026-10-11 17:00:00');

SET @event_time = NULL; SET @app_user_id = NULL;

-- Quick sanity check after loading
SELECT 'Requests' AS TableName, COUNT(*) AS Rows_ FROM Maintenance_Request
UNION ALL SELECT 'Assignments', COUNT(*) FROM Assignment
UNION ALL SELECT 'Work logs', COUNT(*) FROM Work_Log
UNION ALL SELECT 'Status history', COUNT(*) FROM Status_History
UNION ALL SELECT 'Feedback', COUNT(*) FROM Feedback;

-- ============================================================================
-- 3. THE 7 MANDATORY ANALYTICAL QUERIES & VIEWS
-- Reporting clock: views cannot hold session variables in MySQL, so ageing is
-- computed in the SELECT using @as_of (use NOW() in live operation).
-- ============================================================================
SET @as_of = '2026-10-12 09:00:00';

-- ============================================================================
-- REPORT 1: PENDING REQUESTS (VIEW + SLA FLAG)
-- Demonstrates: CREATE VIEW, 5-way JOIN, LEFT JOIN, COALESCE, CASE
-- ============================================================================
CREATE OR REPLACE VIEW vw_PendingRequests AS
SELECT r.RequestID, r.RequestNo, b.BuildingName, rm.RoomNo, c.CategoryName,
       p.PriorityID, p.PriorityName, p.TargetHours, r.Status, r.CreatedAt,
       t.FullName AS AssignedTo
FROM Maintenance_Request r
JOIN Room rm     ON r.RoomID = rm.RoomID
JOIN Building b  ON rm.BuildingID = b.BuildingID
JOIN Category c  ON r.CategoryID = c.CategoryID
JOIN Priority p  ON r.PriorityID = p.PriorityID
LEFT JOIN Assignment a ON a.RequestID = r.RequestID AND a.Status = 'Active'
LEFT JOIN Technician t ON a.TechID = t.TechID
WHERE r.Status IN ('Open', 'Assigned', 'In Progress', 'On Hold');

SELECT v.RequestNo, v.BuildingName, v.RoomNo, v.CategoryName, v.PriorityName, v.Status,
       COALESCE(v.AssignedTo, 'unassigned') AS AssignedTo,
       ROUND(TIMESTAMPDIFF(MINUTE, v.CreatedAt, @as_of) / 60.0, 1) AS AgeHours,
       CASE WHEN v.Status = 'Open'
             AND TIMESTAMPDIFF(MINUTE, v.CreatedAt, @as_of) / 60.0 > v.TargetHours
            THEN 'SLA BREACH' ELSE 'OK' END AS ResponseSLA
FROM vw_PendingRequests v
ORDER BY v.PriorityID, v.CreatedAt;

-- ============================================================================
-- REPORT 2: REQUEST AGEING BUCKETS
-- Demonstrates: DERIVED TABLE (subquery), CASE bucketing, GROUP BY, COUNT/SUM/AVG
-- ============================================================================
SELECT CASE WHEN x.AgeHrs < 24  THEN '1. Under 1 day'
            WHEN x.AgeHrs < 72  THEN '2. 1 to 3 days'
            WHEN x.AgeHrs < 168 THEN '3. 3 to 7 days'
            ELSE '4. Over 7 days' END AS AgeBucket,
       COUNT(*) AS PendingCount,
       SUM(CASE WHEN x.PriorityName IN ('Critical', 'High') THEN 1 ELSE 0 END) AS UrgentCount,
       ROUND(AVG(x.AgeHrs) / 24.0, 1) AS AvgAgeDays
FROM (SELECT v.PriorityName, TIMESTAMPDIFF(MINUTE, v.CreatedAt, @as_of) / 60.0 AS AgeHrs
      FROM vw_PendingRequests v) x
GROUP BY AgeBucket
ORDER BY AgeBucket;

-- ============================================================================
-- REPORT 3: RESPONSE TIME VS PRIORITY TARGET
-- Demonstrates: SUBQUERY with MIN(), GROUP BY, conditional aggregation
-- ============================================================================
SELECT p.PriorityName, p.TargetHours,
       COUNT(*) AS RequestsAssigned,
       ROUND(AVG(x.RespMin) / 60.0, 1) AS AvgResponseHrs,
       ROUND(MAX(x.RespMin) / 60.0, 1) AS WorstResponseHrs,
       ROUND(100.0 * SUM(CASE WHEN x.RespMin <= p.TargetHours * 60 THEN 1 ELSE 0 END) / COUNT(*), 0) AS PctWithinTarget
FROM (SELECT r.RequestID, r.PriorityID,
             TIMESTAMPDIFF(MINUTE, r.CreatedAt, MIN(a.AssignedAt)) AS RespMin
      FROM Maintenance_Request r
      JOIN Assignment a ON a.RequestID = r.RequestID
      GROUP BY r.RequestID, r.PriorityID) x
JOIN Priority p ON x.PriorityID = p.PriorityID
GROUP BY p.PriorityID, p.PriorityName, p.TargetHours
ORDER BY p.PriorityID;

-- ============================================================================
-- REPORT 4: TECHNICIAN LOAD & AVAILABILITY (VIEW)
-- Demonstrates: CREATE VIEW, LEFT JOINs to aggregated subqueries, COALESCE
-- ============================================================================
CREATE OR REPLACE VIEW vw_TechnicianLoad AS
SELECT t.TechID, t.FullName, c.CategoryName AS Speciality, t.MaxActiveJobs,
       COALESCE(act.Cnt, 0)  AS ActiveJobs,
       ROUND(100.0 * COALESCE(act.Cnt, 0) / t.MaxActiveJobs, 0) AS LoadPct,
       COALESCE(done.Cnt, 0) AS JobsCompleted,
       COALESCE(hrs.Total, 0) AS HoursLogged,
       CASE WHEN t.IsActive = 0 THEN 'ON LEAVE'
            WHEN COALESCE(act.Cnt, 0) >= t.MaxActiveJobs THEN 'FULL'
            ELSE 'AVAILABLE' END AS Availability
FROM Technician t
JOIN Category c ON t.CategoryID = c.CategoryID
LEFT JOIN (SELECT TechID, COUNT(*) AS Cnt FROM Assignment
           WHERE Status = 'Active' GROUP BY TechID) act ON act.TechID = t.TechID
LEFT JOIN (SELECT TechID, COUNT(*) AS Cnt FROM Assignment
           WHERE Status = 'Completed' GROUP BY TechID) done ON done.TechID = t.TechID
LEFT JOIN (SELECT a.TechID, SUM(wl.HoursSpent) AS Total FROM Work_Log wl
           JOIN Assignment a ON wl.AssignmentID = a.AssignmentID
           GROUP BY a.TechID) hrs ON hrs.TechID = t.TechID;

SELECT * FROM vw_TechnicianLoad ORDER BY LoadPct DESC, FullName;

-- ============================================================================
-- REPORT 5: BUILDING-WISE MAINTENANCE COST
-- Demonstrates: CREATE VIEW with correlated subqueries, JOIN, GROUP BY, HAVING
-- ============================================================================
CREATE OR REPLACE VIEW vw_RequestCost AS
SELECT r.RequestID, r.RequestNo, rm.BuildingID,
       COALESCE((SELECT SUM(mu.Quantity * mu.UnitCost)
                 FROM Material_Usage mu
                 JOIN Work_Log wl   ON mu.LogID = wl.LogID
                 JOIN Assignment a  ON wl.AssignmentID = a.AssignmentID
                 WHERE a.RequestID = r.RequestID), 0) AS MaterialCost,
       COALESCE((SELECT SUM(rc.Amount) FROM Request_Cost rc
                 WHERE rc.RequestID = r.RequestID), 0) AS ServiceCost
FROM Maintenance_Request r
JOIN Room rm ON r.RoomID = rm.RoomID;

SELECT b.BuildingName,
       COUNT(*) AS Requests,
       SUM(vc.MaterialCost) AS MaterialCost,
       SUM(vc.ServiceCost)  AS ServiceCost,
       SUM(vc.MaterialCost + vc.ServiceCost) AS TotalCost,
       ROUND(AVG(vc.MaterialCost + vc.ServiceCost), 0) AS AvgPerRequest
FROM vw_RequestCost vc
JOIN Building b ON vc.BuildingID = b.BuildingID
GROUP BY b.BuildingID, b.BuildingName
HAVING SUM(vc.MaterialCost + vc.ServiceCost) > 0
ORDER BY TotalCost DESC;

-- ============================================================================
-- REPORT 6: MATERIAL USE & REORDER ALERTS
-- Demonstrates: 4-way JOIN, SUM, COUNT(DISTINCT), RANK() window function
-- ============================================================================
SELECT m.MaterialName, m.Unit,
       SUM(mu.Quantity) AS QtyUsed,
       COUNT(DISTINCT a.RequestID) AS RequestsServed,
       SUM(mu.Quantity * mu.UnitCost) AS TotalCost,
       m.StockQty AS StockLeft,
       CASE WHEN m.StockQty <= m.ReorderLevel THEN 'REORDER' ELSE 'OK' END AS StockStatus,
       RANK() OVER (ORDER BY SUM(mu.Quantity * mu.UnitCost) DESC) AS CostRank
FROM Material m
JOIN Material_Usage mu ON mu.MaterialID = m.MaterialID
JOIN Work_Log wl       ON mu.LogID = wl.LogID
JOIN Assignment a      ON wl.AssignmentID = a.AssignmentID
GROUP BY m.MaterialID, m.MaterialName, m.Unit, m.StockQty, m.ReorderLevel
ORDER BY CostRank, m.MaterialName;

-- ============================================================================
-- REPORT 7: FEEDBACK ANALYSIS (VIEW + NESTED QUERY)
-- Demonstrates: CREATE VIEW, LEFT JOIN, AVG, correlated subquery against category average
-- ============================================================================
CREATE OR REPLACE VIEW vw_FeedbackSummary AS
SELECT c.CategoryName,
       COUNT(f.FeedbackID) AS Responses,
       ROUND(AVG(f.Rating), 2) AS AvgRating,
       MIN(f.Rating) AS LowestRating,
       SUM(CASE WHEN f.Rating >= 4 THEN 1 ELSE 0 END) AS SatisfiedCount
FROM Category c
LEFT JOIN Maintenance_Request r ON r.CategoryID = c.CategoryID
LEFT JOIN Feedback f ON f.RequestID = r.RequestID
GROUP BY c.CategoryID, c.CategoryName;

SELECT * FROM vw_FeedbackSummary ORDER BY AvgRating DESC;

-- Requests rated below the average of their own category (correlated subquery)
SELECT r.RequestNo, c.CategoryName, t.FullName AS Technician, f.Rating, f.Comments
FROM Feedback f
JOIN Maintenance_Request r ON f.RequestID = r.RequestID
JOIN Category c   ON r.CategoryID = c.CategoryID
JOIN Assignment a ON a.RequestID = r.RequestID AND a.Status = 'Completed'
JOIN Technician t ON a.TechID = t.TechID
WHERE f.Rating < (SELECT AVG(f2.Rating)
                  FROM Feedback f2
                  JOIN Maintenance_Request r2 ON f2.RequestID = r2.RequestID
                  WHERE r2.CategoryID = r.CategoryID)
ORDER BY f.Rating, r.RequestNo;

-- ============================================================================
-- 4. NEGATIVE TESTS: each statement below MUST FAIL (kept commented so the script runs clean)
-- Remove the leading '-- ' on one line at a time during the demo.
-- ============================================================================
-- TEST 1: Closing without remarks (request awaiting closure)
-- UPDATE Maintenance_Request SET Status = 'Closed' WHERE RequestNo = 'REQ-2026-0013';
-- Expected -> Closure Details Required: ClosureRemarks must be provided to close a request.

-- TEST 2: Skipping states (Open -> Resolved)
-- UPDATE Maintenance_Request SET Status = 'Resolved' WHERE RequestNo = 'REQ-2026-0021';
-- Expected -> Invalid Status Transition: this move is not allowed by Status_Transition.

-- TEST 3: Duplicate request number
-- INSERT INTO Maintenance_Request (RequestNo, RequesterID, RoomID, CategoryID, PriorityID, Description, CreatedAt) VALUES ('REQ-2026-0021', 3, 2, 1, 3, 'Duplicate test', '2026-10-12 08:00:00');
-- Expected -> ERROR 1062: Duplicate entry for key RequestNo

-- TEST 4: Assigning an inactive technician
-- INSERT INTO Assignment (RequestID, TechID, AssignedAt) SELECT RequestID, 7, '2026-10-12 08:30:00' FROM Maintenance_Request WHERE RequestNo = 'REQ-2026-0016';
-- Expected -> Assignment Control: technician is inactive (on leave).

-- TEST 5: Technician already at maximum load (Mohd. Irfan, limit 2)
-- INSERT INTO Assignment (RequestID, TechID, AssignedAt) SELECT RequestID, 3, '2026-10-12 08:30:00' FROM Maintenance_Request WHERE RequestNo = 'REQ-2026-0016';
-- Expected -> Assignment Control: technician has reached the maximum number of active jobs.

-- TEST 6: Second active assignment on the same request
-- INSERT INTO Assignment (RequestID, TechID, AssignedAt) SELECT RequestID, 4, '2026-10-12 08:30:00' FROM Maintenance_Request WHERE RequestNo = 'REQ-2026-0019';
-- Expected -> Assignment Control: request already has an active assignment (reassign the old one first).

-- TEST 7: Negative cost
-- INSERT INTO Request_Cost (RequestID, CostType, Amount) SELECT RequestID, 'Other', -50.00 FROM Maintenance_Request WHERE RequestNo = 'REQ-2026-0012';
-- Expected -> ERROR 3819: Check constraint on Request_Cost (Amount >= 0) is violated.

-- TEST 8: Material quantity above stock (Projector Lamp, 2 left)
-- INSERT INTO Material_Usage (LogID, MaterialID, Quantity, UnitCost) VALUES (1, 10, 5, 3800.00);
-- Expected -> Stock Violation: requested material quantity exceeds available stock.

-- TEST 9: Feedback on a request that is not Closed
-- INSERT INTO Feedback (RequestID, Rating, Comments, SubmittedAt) SELECT RequestID, 5, 'Too early', '2026-10-12 09:00:00' FROM Maintenance_Request WHERE RequestNo = 'REQ-2026-0013';
-- Expected -> Integrity Violation: feedback is accepted only for Closed requests.
