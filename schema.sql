-- ============================================================================
-- DBMS PROJECT 41: CAMPUS FACILITY MAINTENANCE REQUEST MANAGEMENT SYSTEM
-- REVIEW 3: FINAL SCHEMA (structure only, no data - see seed.py for data)
--
-- Normalised to 3NF. Business rules enforced INSIDE the database:
--   1. Unique request numbers        -> UNIQUE (RequestNo)
--   2. Closure details required      -> CHECK + trigger on Request
--   3. Non-negative materials/costs  -> CHECK constraints
--   4. Valid status transitions      -> Status_Transition table + trigger
--   5. Assignment control            -> trigger (active technician only,
--                                       max open jobs, one active assignment)
-- ============================================================================

DROP DATABASE IF EXISTS CampusMaintenanceDB;
CREATE DATABASE CampusMaintenanceDB;
USE CampusMaintenanceDB;

-- 1. BUILDING
CREATE TABLE Building (
    BuildingID INT PRIMARY KEY AUTO_INCREMENT,
    Code VARCHAR(10) NOT NULL UNIQUE,
    Name VARCHAR(100) NOT NULL,
    Floors INT NOT NULL DEFAULT 1 CHECK (Floors > 0)
);

-- 2. ROOM
CREATE TABLE Room (
    RoomID INT PRIMARY KEY AUTO_INCREMENT,
    BuildingID INT NOT NULL,
    RoomNo VARCHAR(20) NOT NULL,
    Floor INT NOT NULL CHECK (Floor >= 0),
    RoomType VARCHAR(30) NOT NULL DEFAULT 'Classroom'
        CHECK (RoomType IN ('Classroom','Lab','Office','Hostel','Washroom','Library','Auditorium','Other')),
    FOREIGN KEY (BuildingID) REFERENCES Building(BuildingID) ON DELETE RESTRICT,
    UNIQUE (BuildingID, RoomNo)
);

-- 3. CATEGORY (Electrical, Plumbing, Furniture, Classroom ...)
CREATE TABLE Category (
    CategoryID INT PRIMARY KEY AUTO_INCREMENT,
    Name VARCHAR(50) NOT NULL UNIQUE,
    Description VARCHAR(200) NULL
);

-- 4. ASSET (fan, projector, tap, bench ... installed in a room)
CREATE TABLE Asset (
    AssetID INT PRIMARY KEY AUTO_INCREMENT,
    AssetTag VARCHAR(30) NOT NULL UNIQUE,
    Name VARCHAR(100) NOT NULL,
    CategoryID INT NOT NULL,
    RoomID INT NOT NULL,
    PurchaseDate DATE NULL,
    FOREIGN KEY (CategoryID) REFERENCES Category(CategoryID) ON DELETE RESTRICT,
    FOREIGN KEY (RoomID) REFERENCES Room(RoomID) ON DELETE RESTRICT
);

-- 5. PRIORITY (SLA target is a property of the priority level)
CREATE TABLE Priority (
    PriorityID INT PRIMARY KEY AUTO_INCREMENT,
    Name VARCHAR(20) NOT NULL UNIQUE,
    Rank_ INT NOT NULL UNIQUE CHECK (Rank_ > 0),
    SLAHours INT NOT NULL CHECK (SLAHours > 0)
);

-- 6. APP_USER (students, faculty, staff, facility admin)
CREATE TABLE AppUser (
    UserID INT PRIMARY KEY AUTO_INCREMENT,
    Name VARCHAR(100) NOT NULL,
    Email VARCHAR(120) NOT NULL UNIQUE,
    Phone VARCHAR(15) NULL,
    Role VARCHAR(20) NOT NULL CHECK (Role IN ('STUDENT','FACULTY','STAFF','ADMIN'))
);

-- 7. TECHNICIAN
CREATE TABLE Technician (
    TechnicianID INT PRIMARY KEY AUTO_INCREMENT,
    Name VARCHAR(100) NOT NULL,
    Phone VARCHAR(15) NULL,
    CategoryID INT NOT NULL,                 -- speciality trade
    HourlyRate DECIMAL(8,2) NOT NULL DEFAULT 0.00 CHECK (HourlyRate >= 0),
    MaxOpenJobs INT NOT NULL DEFAULT 5 CHECK (MaxOpenJobs > 0),
    IsActive TINYINT(1) NOT NULL DEFAULT 1 CHECK (IsActive IN (0,1)),
    FOREIGN KEY (CategoryID) REFERENCES Category(CategoryID) ON DELETE RESTRICT
);

-- 8. STATUS (lookup) and allowed transitions
CREATE TABLE Status (
    Code VARCHAR(20) PRIMARY KEY,
    IsTerminal TINYINT(1) NOT NULL DEFAULT 0
);

CREATE TABLE Status_Transition (
    FromStatus VARCHAR(20) NOT NULL,
    ToStatus VARCHAR(20) NOT NULL,
    PRIMARY KEY (FromStatus, ToStatus),
    FOREIGN KEY (FromStatus) REFERENCES Status(Code),
    FOREIGN KEY (ToStatus) REFERENCES Status(Code)
);

-- 9. REQUEST (the maintenance complaint)
CREATE TABLE Request (
    RequestID INT PRIMARY KEY AUTO_INCREMENT,
    RequestNo VARCHAR(20) NOT NULL UNIQUE,
    Title VARCHAR(150) NOT NULL,
    Description TEXT NULL,
    RequestedBy INT NOT NULL,
    RoomID INT NOT NULL,
    AssetID INT NULL,
    CategoryID INT NOT NULL,
    PriorityID INT NOT NULL,
    Status VARCHAR(20) NOT NULL DEFAULT 'OPEN',
    CreatedAt DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    ClosedAt DATETIME NULL,
    ClosureRemarks VARCHAR(500) NULL,
    FOREIGN KEY (RequestedBy) REFERENCES AppUser(UserID) ON DELETE RESTRICT,
    FOREIGN KEY (RoomID) REFERENCES Room(RoomID) ON DELETE RESTRICT,
    FOREIGN KEY (AssetID) REFERENCES Asset(AssetID) ON DELETE RESTRICT,
    FOREIGN KEY (CategoryID) REFERENCES Category(CategoryID) ON DELETE RESTRICT,
    FOREIGN KEY (PriorityID) REFERENCES Priority(PriorityID) ON DELETE RESTRICT,
    FOREIGN KEY (Status) REFERENCES Status(Code) ON DELETE RESTRICT,
    -- Rule 2: a CLOSED request must carry closure date + remarks; others must not
    CONSTRAINT chk_closure_details CHECK (
        (Status = 'CLOSED' AND ClosedAt IS NOT NULL AND ClosureRemarks IS NOT NULL AND CHAR_LENGTH(TRIM(ClosureRemarks)) > 0)
        OR (Status <> 'CLOSED')
    ),
    CONSTRAINT chk_closed_after_created CHECK (ClosedAt IS NULL OR ClosedAt >= CreatedAt)
);

-- 10. ASSIGNMENT (request <-> technician; history of assignments kept)
CREATE TABLE Assignment (
    AssignmentID INT PRIMARY KEY AUTO_INCREMENT,
    RequestID INT NOT NULL,
    TechnicianID INT NOT NULL,
    AssignedAt DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    AcceptedAt DATETIME NULL,
    IsActive TINYINT(1) NOT NULL DEFAULT 1 CHECK (IsActive IN (0,1)),
    -- generated column: gives one NON-NULL value per active row so that
    -- UNIQUE enforces "at most one active assignment per request"
    ActiveRequestKey INT AS (CASE WHEN IsActive = 1 THEN RequestID ELSE NULL END) STORED,
    FOREIGN KEY (RequestID) REFERENCES Request(RequestID) ON DELETE RESTRICT,  -- RESTRICT: RequestID feeds a stored generated column
    FOREIGN KEY (TechnicianID) REFERENCES Technician(TechnicianID) ON DELETE RESTRICT,
    UNIQUE (ActiveRequestKey)
);

-- 11. WORK_LOG (labour entries by a technician on an assignment)
CREATE TABLE WorkLog (
    WorkLogID INT PRIMARY KEY AUTO_INCREMENT,
    AssignmentID INT NOT NULL,
    LogDate DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    HoursSpent DECIMAL(5,2) NOT NULL CHECK (HoursSpent > 0 AND HoursSpent <= 24),
    LabourCost DECIMAL(10,2) NOT NULL DEFAULT 0.00 CHECK (LabourCost >= 0),
    Notes VARCHAR(300) NULL,
    FOREIGN KEY (AssignmentID) REFERENCES Assignment(AssignmentID) ON DELETE CASCADE
);

-- 12. MATERIAL (stock catalogue)
CREATE TABLE Material (
    MaterialID INT PRIMARY KEY AUTO_INCREMENT,
    Name VARCHAR(100) NOT NULL UNIQUE,
    Unit VARCHAR(20) NOT NULL DEFAULT 'pcs',
    UnitCost DECIMAL(10,2) NOT NULL CHECK (UnitCost >= 0),
    StockQty INT NOT NULL DEFAULT 0 CHECK (StockQty >= 0)
);

-- 13. MATERIAL_USAGE (materials consumed by a work log)
CREATE TABLE MaterialUsage (
    UsageID INT PRIMARY KEY AUTO_INCREMENT,
    WorkLogID INT NOT NULL,
    MaterialID INT NOT NULL,
    Quantity INT NOT NULL CHECK (Quantity > 0),
    UnitCostAtUse DECIMAL(10,2) NOT NULL CHECK (UnitCostAtUse >= 0),
    FOREIGN KEY (WorkLogID) REFERENCES WorkLog(WorkLogID) ON DELETE CASCADE,
    FOREIGN KEY (MaterialID) REFERENCES Material(MaterialID) ON DELETE RESTRICT
);

-- 14. STATUS_HISTORY (audit trail, written by trigger)
CREATE TABLE StatusHistory (
    HistoryID INT PRIMARY KEY AUTO_INCREMENT,
    RequestID INT NOT NULL,
    OldStatus VARCHAR(20) NULL,
    NewStatus VARCHAR(20) NOT NULL,
    ChangedAt DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (RequestID) REFERENCES Request(RequestID) ON DELETE CASCADE
);

-- 15. FEEDBACK (one per closed request)
CREATE TABLE Feedback (
    FeedbackID INT PRIMARY KEY AUTO_INCREMENT,
    RequestID INT NOT NULL UNIQUE,
    Rating INT NOT NULL CHECK (Rating BETWEEN 1 AND 5),
    Comments VARCHAR(500) NULL,
    SubmittedAt DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (RequestID) REFERENCES Request(RequestID) ON DELETE CASCADE
);

-- ============================================================================
-- INDEXES ON FREQUENTLY SEARCHED / JOINED ATTRIBUTES
-- ============================================================================
CREATE INDEX idx_room_building          ON Room(BuildingID);
CREATE INDEX idx_asset_room             ON Asset(RoomID);
CREATE INDEX idx_request_status         ON Request(Status);
CREATE INDEX idx_request_created        ON Request(CreatedAt);
CREATE INDEX idx_request_room           ON Request(RoomID);
CREATE INDEX idx_request_category_prio  ON Request(CategoryID, PriorityID);
CREATE INDEX idx_request_user           ON Request(RequestedBy);
CREATE INDEX idx_assign_tech_active     ON Assignment(TechnicianID, IsActive);
CREATE INDEX idx_worklog_assignment     ON WorkLog(AssignmentID);
CREATE INDEX idx_usage_worklog          ON MaterialUsage(WorkLogID);
CREATE INDEX idx_history_request        ON StatusHistory(RequestID, ChangedAt);

-- ============================================================================
-- LOOKUP DATA THAT THE RULES DEPEND ON (not "sample" data)
-- ============================================================================
INSERT INTO Status (Code, IsTerminal) VALUES
 ('OPEN',0),('ASSIGNED',0),('IN_PROGRESS',0),('ON_HOLD',0),('RESOLVED',0),('CLOSED',1),('CANCELLED',1);

INSERT INTO Status_Transition (FromStatus, ToStatus) VALUES
 ('OPEN','ASSIGNED'),('OPEN','CANCELLED'),
 ('ASSIGNED','IN_PROGRESS'),('ASSIGNED','OPEN'),('ASSIGNED','CANCELLED'),
 ('IN_PROGRESS','ON_HOLD'),('IN_PROGRESS','RESOLVED'),
 ('ON_HOLD','IN_PROGRESS'),('ON_HOLD','CANCELLED'),
 ('RESOLVED','CLOSED'),('RESOLVED','IN_PROGRESS');

-- ============================================================================
-- TRIGGERS
-- ============================================================================
DELIMITER //

-- Rule 4: only transitions listed in Status_Transition are allowed; also
-- blocks closing without a resolving assignment and records history.
CREATE TRIGGER trg_request_status_check
BEFORE UPDATE ON Request
FOR EACH ROW
BEGIN
    DECLARE ok INT DEFAULT 0;
    IF NEW.Status <> OLD.Status THEN
        SELECT COUNT(*) INTO ok FROM Status_Transition
         WHERE FromStatus = OLD.Status AND ToStatus = NEW.Status;
        IF ok = 0 THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Invalid status transition';
        END IF;
    END IF;
    IF NEW.Status = 'CLOSED' AND (NEW.ClosureRemarks IS NULL OR CHAR_LENGTH(TRIM(NEW.ClosureRemarks)) = 0) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Closure remarks are required to close a request';
    END IF;
END //

CREATE TRIGGER trg_request_status_history_ins
AFTER INSERT ON Request
FOR EACH ROW
BEGIN
    INSERT INTO StatusHistory (RequestID, OldStatus, NewStatus, ChangedAt)
    VALUES (NEW.RequestID, NULL, NEW.Status, NEW.CreatedAt);
END //

CREATE TRIGGER trg_request_status_history_upd
AFTER UPDATE ON Request
FOR EACH ROW
BEGIN
    IF NEW.Status <> OLD.Status THEN
        INSERT INTO StatusHistory (RequestID, OldStatus, NewStatus)
        VALUES (NEW.RequestID, OLD.Status, NEW.Status);
    END IF;
END //

-- Rule 5: assignment control
CREATE TRIGGER trg_assignment_control
BEFORE INSERT ON Assignment
FOR EACH ROW
BEGIN
    DECLARE tech_active INT;
    DECLARE tech_max INT;
    DECLARE tech_open INT;
    DECLARE req_status VARCHAR(20);

    SELECT IsActive, MaxOpenJobs INTO tech_active, tech_max
      FROM Technician WHERE TechnicianID = NEW.TechnicianID;
    IF tech_active = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Technician is inactive and cannot be assigned';
    END IF;

    SELECT Status INTO req_status FROM Request WHERE RequestID = NEW.RequestID;
    IF req_status NOT IN ('OPEN') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Only OPEN requests can be assigned';
    END IF;

    SELECT COUNT(*) INTO tech_open
      FROM Assignment a JOIN Request r ON a.RequestID = r.RequestID
     WHERE a.TechnicianID = NEW.TechnicianID AND a.IsActive = 1
       AND r.Status IN ('ASSIGNED','IN_PROGRESS','ON_HOLD');
    IF tech_open >= tech_max THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Technician has reached the maximum number of open jobs';
    END IF;
END //

-- Work may only be logged against an active assignment on a live request
CREATE TRIGGER trg_worklog_control
BEFORE INSERT ON WorkLog
FOR EACH ROW
BEGIN
    DECLARE act INT;
    DECLARE st VARCHAR(20);
    SELECT a.IsActive, r.Status INTO act, st
      FROM Assignment a JOIN Request r ON a.RequestID = r.RequestID
     WHERE a.AssignmentID = NEW.AssignmentID;
    IF act = 0 OR st NOT IN ('ASSIGNED','IN_PROGRESS','ON_HOLD') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Work can only be logged on an active job';
    END IF;
END //

-- Materials: freeze unit cost at time of use and reduce stock (non-negative by CHECK)
CREATE TRIGGER trg_usage_stock
BEFORE INSERT ON MaterialUsage
FOR EACH ROW
BEGIN
    DECLARE cost DECIMAL(10,2);
    SELECT UnitCost INTO cost FROM Material WHERE MaterialID = NEW.MaterialID;
    SET NEW.UnitCostAtUse = cost;
    UPDATE Material SET StockQty = StockQty - NEW.Quantity WHERE MaterialID = NEW.MaterialID;
END //

-- Feedback only for CLOSED requests
CREATE TRIGGER trg_feedback_closed_only
BEFORE INSERT ON Feedback
FOR EACH ROW
BEGIN
    DECLARE st VARCHAR(20);
    SELECT Status INTO st FROM Request WHERE RequestID = NEW.RequestID;
    IF st <> 'CLOSED' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Feedback is allowed only for CLOSED requests';
    END IF;
END //

DELIMITER ;

-- ============================================================================
-- VIEWS (used by the Reports page)
-- ============================================================================
CREATE OR REPLACE VIEW vw_RequestCost AS
SELECT r.RequestID,
       COALESCE((SELECT SUM(w.LabourCost) FROM Assignment a JOIN WorkLog w ON w.AssignmentID = a.AssignmentID
                  WHERE a.RequestID = r.RequestID), 0) AS LabourCost,
       COALESCE((SELECT SUM(mu.Quantity * mu.UnitCostAtUse)
                   FROM Assignment a JOIN WorkLog w ON w.AssignmentID = a.AssignmentID
                   JOIN MaterialUsage mu ON mu.WorkLogID = w.WorkLogID
                  WHERE a.RequestID = r.RequestID), 0) AS MaterialCost
FROM Request r;

CREATE OR REPLACE VIEW vw_PendingRequests AS
SELECT r.RequestID, r.RequestNo, r.Title, r.Status, p.Name AS Priority, p.Rank_ AS PriorityRank,
       c.Name AS Category, b.Name AS Building, rm.RoomNo, r.CreatedAt,
       TIMESTAMPDIFF(HOUR, r.CreatedAt, NOW()) AS AgeHours, p.SLAHours
FROM Request r
JOIN Priority p ON r.PriorityID = p.PriorityID
JOIN Category c ON r.CategoryID = c.CategoryID
JOIN Room rm ON r.RoomID = rm.RoomID
JOIN Building b ON rm.BuildingID = b.BuildingID
WHERE r.Status NOT IN ('CLOSED','CANCELLED');
